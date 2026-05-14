# simple-semver

A GitHub action that updates semantic version tags (`major.minor.patch`) based on the matching pull request label (`major`, `minor`, or `patch`), defaults to `patch` if no label is specified.

## Why This Action

- Easy to use: Set the PR label to what you want to bump
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
| `version-bump` | `""` | Explicit bump to apply: `major`, `minor`, or `patch`. Most useful for manual `workflow_dispatch` runs. |
| `tag-prefix` | `v` | Prefix to apply to tags (for example `v1.2.3`). |
| `write-tag` | `"false"` | When `true`, creates and pushes the computed tag to `origin` with retry-safe collision handling. |
| `label_branch` | `""` | Optional `workflow_dispatch` input in this repo's `release_build.yaml` that scopes PR-label lookup to a base branch. If empty, default branch is used. |

## Outputs

- `new-tag`: computed next tag (for example `v1.4.2`)
- `previous-tag`: latest existing tag used as the bump source
- `version-bump-used`: resolved bump type actually applied

## What part of the version gets bumped?

The version always follows `major.minor.patch`.

- In this repo's release workflow, bump type is resolved from PR labels: `major`, `minor`, or `patch`.
- If no matching label is found, it defaults to `patch`.
- For manual `workflow_dispatch` runs, `version-bump` can explicitly override bump type.


## Label-Driven Release Workflow (Optional)

If you use this repo's `release_build.yaml` pattern, version bump can be resolved from pull request labels:

- supported labels: `major`, `minor`, `patch`
- if none are present, defaults to `patch`
- if multiple are present, workflow fails fast
- optional `workflow_dispatch` input `label_branch` can scope label lookup to a specific base branch (otherwise uses repository default branch)

This keeps release behavior simple and explicit while preserving manual override via `workflow_dispatch` `version_bump`.

## Notes

- Ensure `actions/checkout` uses `fetch-depth: 0` in workflows that depend on tags.
- For repositories with concurrent release jobs, keep `write-tag: "true"` to use built-in retry-safe tag writes.
