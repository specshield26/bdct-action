#!/usr/bin/env bash
#
# Non-breaking baseline validation for action.yml (dependency-free: bash + awk + grep).
#
# The action's inputs are the public contract every consumer workflow binds to,
# and every input maps to a specshield CLI flag. Removing/renaming an input, an
# output, or drifting the cli-version default off the published 3.3.x line is a
# breaking change. This script fails loudly if any of that happens.
#
# Run: scripts/check-action.sh   (exit 0 = intact, 1 = a documented key changed)

set -uo pipefail
cd "$(dirname "$0")/.."

ACTION="action.yml"
[ -f "$ACTION" ] || { echo "FAIL: $ACTION not found"; exit 1; }

fail=0

# Print the `  <name>:` keys inside a top-level YAML block: from the block
# header (e.g. "inputs:") up to the next top-level header (e.g. "outputs:").
block_keys() { # $1 = start header, $2 = end header
  awk -v s="^$1" -v e="^$2" '
    $0 ~ s { inb=1; next }
    inb && $0 ~ e { inb=0 }
    inb && /^  [a-z0-9_-]+:/ { sub(/:.*/, ""); gsub(/ /, ""); print }
  ' "$ACTION"
}

check_keys() { # $1 = label, $2 = expected (space list), $3 = actual (newline list)
  local label="$1" expected="$2" actual="$3" k
  for k in $expected; do
    if ! grep -qx "$k" <<< "$actual"; then
      echo "FAIL: $label missing expected key: $k"
      fail=1
    fi
  done
}

INPUTS_EXPECTED="command api-token org provider consumer service version consumer-version provider-version spec contract format branch env cli-version server fail-on-error"
OUTPUTS_EXPECTED="json exit-code deployable verification-id status"

check_keys "inputs"  "$INPUTS_EXPECTED"  "$(block_keys 'inputs:'  'outputs:')"
check_keys "outputs" "$OUTPUTS_EXPECTED" "$(block_keys 'outputs:' 'runs:')"

# cli-version default must stay on the ~3.3.x line — the floor MUST be a
# published npm version, and patches within 3.3 auto-roll-out. Bumping the minor
# (or an exact pin off 3.3) is a deliberate release decision, not a silent edit.
if ! grep -Eq "default: *'~3\.3\.[0-9]+'" "$ACTION"; then
  echo "FAIL: cli-version default is not on the ~3.3.x line"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "PASS: action.yml inputs (17), outputs (5), and cli-version default (~3.3.x) are intact"
fi
exit $fail
