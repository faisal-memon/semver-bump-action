# simple-semver

A GitHub action that updates semantic version tags (`major`.`minor`.`patch`) based on the matching pull request label (`major`, `minor`, or `patch`). Defaults to `patch` if no label is specified.

## Why This Action?

- Easy to use: set the PR label to what you want to bump
- Safe baseline behavior: if no tags exist, starts from `v0.0.0`.
- Collision-safe behavior: fails on tag collision and instructs enabling workflow concurrency.

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
        uses: faisal-memon/simple-semver@v0.0.15
        with:
          write-tag: "true"
          write-major-tag: "true"
          github-token: ${{ github.token }}

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
| `github-token` | `""` | Token used to query PR labels. Required when `version-bump` is empty (or provide `GITHUB_TOKEN` env). |
| `tag-prefix` | `v` | Prefix to apply to tags (for example `v1.2.3`). |
| `version-bump` | `""` | Explicit bump override: `major`, `minor`, or `patch`. If empty, action resolves from PR labels and defaults to `patch`. |
| `write-tag` | `"true"` | When `true`, creates and pushes the computed tag to `origin`. If tag already exists, action fails and asks to enable workflow concurrency. |
| `write-major-tag` | `"false"` | When `true` and `write-tag` is `true`, moves and pushes floating major tag (for example `v1` or `v0`). |

## Outputs

- `new-tag`: computed next tag (for example `v1.4.2`)
- `previous-tag`: latest existing tag used as the bump source
- `version-bump-used`: resolved bump type actually applied

## What part of the version gets bumped?

The version always follows `major.minor.patch`.

- If `version-bump` is provided, it is used directly.
- Otherwise, the action checks labels (`major`, `minor`, `patch`) on the PR associated with the commit.
- If no matching label is found, it defaults to `patch`.
- If label resolution prerequisites are missing (`github-token`/`GITHUB_TOKEN`, `jq`, `curl`, `GITHUB_REF_NAME`, or required GitHub context), the action fails fast.


## Label-Driven Release Workflow (Optional)

This action can resolve version bump from pull request labels:

- supported labels: `major`, `minor`, `patch`
- if none are present, defaults to `patch`
- if multiple are present, workflow fails fast
- branch used for label lookup is the triggering branch

This keeps release behavior simple and explicit while preserving manual override via `workflow_dispatch` `version_bump`.

## Notes

- Ensure `actions/checkout` uses `fetch-depth: 0` in workflows that depend on tags.
- For repositories with concurrent release jobs, enable workflow `concurrency` with `cancel-in-progress: false` to avoid tag collisions.
