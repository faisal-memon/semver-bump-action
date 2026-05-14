# simple-semver

A GitHub action that updates semantic version tags (`major`.`minor`.`patch`) based on the matching pull request label (`major`, `minor`, or `patch`). Defaults to `patch` if no label is specified.

## Why This Action?

- Easy to use: set the PR label to what you want to bump
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

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v3
        with:
          tag_name: ${{ steps.bump.outputs.new-tag }}
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

> [!NOTE]
> Requires workflow permissions: `contents: write` to be able to write the semantic version tag

## Inputs

| Input | Default | Description |
| --- | --- | --- |
| `tag-prefix` | `v` | Prefix to apply to tags (for example `v1.2.3`). |
| `version-bump` | `""` | Explicit bump override: `major`, `minor`, or `patch`. If empty, action resolves from PR labels, then commit hints, then defaults to `patch`. |
| `label-branch` | `""` | Optional branch used to select associated PR labels. Defaults to the triggering branch. |
| `github-token` | `""` | Optional token used to query PR labels. If empty, action falls back to `GITHUB_TOKEN` env when available. |
| `write-tag` | `"true"` | When `true`, creates and pushes the computed tag to `origin` with retry-safe collision handling. |

## Outputs

- `new-tag`: computed next tag (for example `v1.4.2`)
- `previous-tag`: latest existing tag used as the bump source
- `version-bump-used`: resolved bump type actually applied

## What part of the version gets bumped?

The version always follows `major.minor.patch`.

- If `version-bump` is provided, it is used directly.
- Otherwise, the action checks labels (`major`, `minor`, `patch`) on the PR associated with the commit.
- If no matching label is found, commit hints are used when present: `[major]`, `[minor]`, `[patch]`, `#major`, `#minor`, `#patch`.
- If neither labels nor hints resolve a bump, it defaults to `patch`.


## Label-Driven Release Workflow (Optional)

This action can resolve version bump from pull request labels:

- supported labels: `major`, `minor`, `patch`
- if none are present, defaults to `patch`
- if multiple are present, workflow fails fast
- branch used for label lookup defaults to the triggering branch (or `label-branch` if set)

This keeps release behavior simple and explicit while preserving manual override via `workflow_dispatch` `version_bump`.

## Notes

- Ensure `actions/checkout` uses `fetch-depth: 0` in workflows that depend on tags.
- For repositories with concurrent release jobs, keep `write-tag: "true"` to use built-in retry-safe tag writes.
