# SpecShield BDCT — GitHub Action

[![GitHub Marketplace](https://img.shields.io/badge/marketplace-specshield--bdct-blue?logo=github)](https://github.com/marketplace/actions/specshield-bdct)
[![License](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

Run [SpecShield](https://specshield.io) Bi-Directional Contract Testing in your GitHub Actions pipelines.
Publish provider OpenAPI specs, publish consumer contracts, verify compatibility, and gate deployments
with `can-i-deploy` — all without hand-writing the YAML.

```yaml
- uses: specshield26/bdct-action@v1
  with:
    command: can-i-deploy
    org: ${{ vars.SPECSHIELD_ORG }}
    service: payment-service
    version: ${{ github.sha }}
    env: production
    api-token: ${{ secrets.SPECSHIELD_API_KEY }}
```

If the contract is broken, the action exits non-zero and the deploy job is skipped.

---

## What this action does

It is a thin, audited wrapper around the `specshield` CLI (v3 and up). Every BDCT subcommand the CLI
exposes is reachable here through the `command` input. The action:

1. Sets up Node 20 on the runner.
2. Caches and installs `specshield` from npm at the requested version.
3. Runs the chosen BDCT subcommand with `--json` so structured output is exposed back to your workflow.
4. Sets typed outputs for the two commands users branch on (`can-i-deploy` → `deployable`, `verify` → `verification-id` and `status`).
5. Writes a one-line result into the GitHub Step Summary so the run page tells you what happened at a glance.

It is a **composite action** — no Docker images, no build-time dependencies, runs on `ubuntu-*`,
`macos-*`, and `windows-*` runners (via the bundled bash shell on Windows).

---

## Quick start

### 1.  Provision an API key

Sign up at [specshield.io](https://specshield.io), generate an API key, and add it to your repo as
`SPECSHIELD_API_KEY`. The Pro plan is required for BDCT operations.

```
Settings → Secrets and variables → Actions → New repository secret
```

Optionally, store your organization key as a repo or org variable named `SPECSHIELD_ORG` so it does
not have to be repeated on every step.

### 2.  Drop the action into a workflow

The three idiomatic entry points are in [`examples/`](examples) — copy any of them straight into your
`.github/workflows/` folder:

| Workflow                                                          | When it fires                                                | What it does                                  |
| ----------------------------------------------------------------- | ------------------------------------------------------------ | --------------------------------------------- |
| [`pr-check.yml`](examples/pr-check.yml)                           | Every pull request that changes the OpenAPI spec             | Verifies the change against published consumers and fails the check if it would break someone. |
| [`publish-on-merge.yml`](examples/publish-on-merge.yml)           | Every push to `main`                                         | Publishes the latest provider spec; auto-verifies all known consumers. |
| [`can-i-deploy-gate.yml`](examples/can-i-deploy-gate.yml)         | Just before the deploy step in your release workflow         | Hard-gates production deploys on contract compatibility. |

---

## Inputs

| Input              | Required                          | Default                  | Description |
| ------------------ | --------------------------------- | ------------------------ | ----------- |
| `command`          | yes                               | —                        | One of `publish-provider`, `publish-consumer`, `verify`, `can-i-deploy`, `matrix`, `list-providers`, `list-consumers`. |
| `api-token`        | yes                               | —                        | Your SpecShield API key. Always pass via a secret. |
| `org`              | yes                               | —                        | Organization key. Required by every backend endpoint. |
| `provider`         | command-dependent                 | —                        | Provider service name. |
| `consumer`         | command-dependent                 | —                        | Consumer service name. |
| `service`          | for `can-i-deploy`                | —                        | Service to gate (consumer or provider — the engine checks both directions). |
| `version`          | for publish + can-i-deploy        | —                        | Version tag. Use `${{ github.sha }}` for immutable per-commit publishing. |
| `consumer-version` | for `verify`                      | —                        | Consumer version to verify. |
| `provider-version` | for `verify`                      | —                        | Provider version to verify against. |
| `spec`             | for `publish-provider`            | —                        | Path to provider OpenAPI spec. |
| `contract`         | for `publish-consumer`            | —                        | Path to consumer contract (OpenAPI YAML/JSON or Pact JSON). |
| `format`           | optional, for `publish-consumer`  | `OPENAPI`                | Contract format: `OPENAPI` or `PACT`. |
| `branch`           | optional                          | —                        | Git branch tag stored alongside a provider spec (purely informational). |
| `env`              | optional                          | —                        | Environment label (e.g. `staging`, `production`). |
| `cli-version`      | optional                          | `latest`                 | npm version of the `specshield` CLI to install. **Pin in production** (e.g. `3.0.0`) for reproducible builds. |
| `server`           | optional                          | `https://specshield.io`  | API base URL. Override only for self-hosted or staging environments. |
| `fail-on-error`    | optional                          | `true`                   | Set `false` if you want to inspect outputs in a later step before failing the job. |

---

## Outputs

| Output            | Set after          | Description |
| ----------------- | ------------------ | ----------- |
| `json`            | every command      | Raw JSON response from the CLI. Parse with `fromJSON()` or `jq`. |
| `exit-code`       | every command      | `0` clean / deployable, `1` breaking / not deployable, `2` config or runtime error. |
| `deployable`      | `can-i-deploy`     | `true` or `false`. |
| `verification-id` | `verify`           | Numeric id of the verification record. |
| `status`          | `verify`           | `COMPATIBLE` or `INCOMPATIBLE`. |

### Branching on outputs

```yaml
- id: gate
  uses: specshield26/bdct-action@v1
  with:
    command: can-i-deploy
    org: ${{ vars.SPECSHIELD_ORG }}
    service: payment-service
    version: ${{ github.sha }}
    env: production
    api-token: ${{ secrets.SPECSHIELD_API_KEY }}
    fail-on-error: false   # do not fail the job here

- name: Deploy
  if: steps.gate.outputs.deployable == 'true'
  run: ./deploy.sh

- name: Notify Slack on block
  if: steps.gate.outputs.deployable == 'false'
  run: |
    REASON=$(echo '${{ steps.gate.outputs.json }}' | jq -r .reason)
    curl -X POST -H 'Content-type: application/json' \
      -d "{\"text\":\"🚫 Blocked by SpecShield: $REASON\"}" \
      ${{ secrets.SLACK_WEBHOOK }}
```

---

## Versioning

This action follows [GitHub's recommended major-version pattern](https://docs.github.com/actions/sharing-automations/creating-actions/about-custom-actions#using-release-management-for-actions).

| Tag         | What it tracks                                                  | Recommended use |
| ----------- | --------------------------------------------------------------- | --------------- |
| `@v1`       | Floating tag — always points to the latest `1.x.y` release      | Most users      |
| `@v1.0.0`   | Immutable per-release tag                                       | Reproducible / audited builds |
| `@main`     | The default branch — may be in flux                             | Don't use in production |

`@v1` will receive backward-compatible features and bug fixes. Breaking changes will land on `@v2`.

---

## Compatibility matrix

| `cli-version` | Backend feature set                                                                  |
| ------------- | ------------------------------------------------------------------------------------ |
| `3.x`         | Full BDCT (publish, verify, can-i-deploy, matrix, list-*); the legacy `contracts` command is removed. |
| `<3.0`        | **Not supported.** Use this action with `cli-version: 3.0.0` or newer.               |

---

## Security notes

- **API tokens** must be passed via `${{ secrets.* }}`. The action injects them as `SPECSHIELD_API_KEY`
  for the CLI to read; they never appear on the command line and are auto-redacted from logs by GitHub.
- The action runs `npm install -g specshield@<cli-version>` on the runner. If you want a fully air-gapped
  build, install the CLI in a dependency-cache step yourself and call `specshield` directly instead.
- Every BDCT request carries the `org` you configure. Cross-tenant data exposure is impossible by design;
  the backend rejects any request whose JWT-resolved customer does not own the given `org`.

---

## License

[MIT](LICENSE).
