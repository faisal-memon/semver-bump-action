# simple-semver

A simple GitHub composite action to compute and optionally push semantic version tags.

## Why This Action

- Small API surface: only `version-bump`, `tag-prefix`, and `write-tag`.
- Safe baseline behavior: if no tags exist, starts from `v0.0.0`.
- Concurrency-aware tag writes: retries with refetch/recompute when a tag collision occurs.

## Quick Start (Tag + Release)

```yaml
name: Release Build

on:
  push:
    branches: [main]

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Bump and write version tag
        id: bump
        uses: faisal-memon/simple-semver@v0.0.9
        with:
          write-tag: "true"

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v3
        with:
          tag_name: ${{ steps.bump.outputs.new-tag }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

> [!NOTE]
> `write-tag: "true"` requires workflow permissions: `contents: write`.

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `version-bump` | `""` | Explicit bump to apply: `major`, `minor`, or `patch`. When empty, bump is inferred from commit markers. |
| `tag-prefix` | `v` | Prefix to apply to tags (for example `v1.2.3`). |
| `write-tag` | `"false"` | When `true`, creates and pushes the computed tag to `origin` with retry-safe collision handling. |

## Outputs

- `new-tag`: computed next tag (for example `v1.4.2`)
- `previous-tag`: latest existing tag used as the bump source
- `version-bump-used`: resolved bump type actually applied

## What part of the version gets bumped?

The version will always follow the `major.minor.patch` format. If the `version-bump` input is provided, then that part of the version is bumped. Setting `version-bump` is useful for `workflow_dispatch:` when you want to select what part of the version to bump. Otherwise, it will look for explicit markers in the GitHub event payload commit messages: `[major]`/`#major`, `[minor]`/`#minor`, or `[patch]`/`#patch`. If no marker is found, it defaults to `patch`.


## Notes

- Ensure `actions/checkout` uses `fetch-depth: 0` in workflows that depend on tags.
- For repositories with concurrent release jobs, keep `write-tag: "true"` to use built-in retry-safe tag writes.
