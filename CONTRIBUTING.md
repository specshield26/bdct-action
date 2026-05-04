# Contributing

## Local development

1.  Edit `action.yml`, the examples, or the README.
2.  Run the lint job locally:

    ```bash
    python3 -c "import yaml; yaml.safe_load(open('action.yml'))"
    ```

3.  Run the action against itself with `uses: ./` from a workflow in this repo.
    See `.github/workflows/test.yml` for the pattern.

## Releasing

1.  Decide the next version, e.g. `v1.2.0`.
2.  Update the version reference in `README.md` if applicable.
3.  Commit and push to `main`.
4.  Tag and push:

    ```bash
    git tag v1.2.0
    git push origin v1.2.0
    ```

    The `release.yml` workflow will:
    - move `v1` to point at `v1.2.0`
    - create the matching GitHub Release with auto-generated notes

5.  **First release only** — open the new release on github.com, edit it, and tick
    *"Publish this Action to the GitHub Marketplace"*. Pick categories
    *Continuous integration* and *API management*. Subsequent releases inherit the
    Marketplace settings.

## Versioning rules

- `v1` is the floating tag; backwards-compatible additions land here.
- Breaking changes (renaming an input, removing an output, raising the minimum
  `cli-version`) must wait for `v2` and a separate Marketplace listing update.
- Pin `cli-version` in the integration test workflow to the latest published
  CLI when bumping. Do not let `latest` drift silently.
