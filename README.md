# semver-bump-action

Reusable GitHub composite action that computes the next semantic version tag from:

- the latest existing git tag
- an explicit bump input
- or commit-message markers like `[major]`, `[minor]`, `[patch]` (also supports `#major/#minor/#patch`)

When no prior tags exist, the action falls back to `v0.0.0` (or `<tag-prefix>0.0.0`) before applying the selected bump.

## What It Does

- Resolves bump type from `version-bump` input when provided.
- Otherwise infers bump type from commit messages in the GitHub event payload.
- Computes `new-tag` from the latest tag.
- Optionally writes/pushes the tag with retry logic to handle concurrent pipeline races.

## Inputs

- `version-bump`
  Explicit bump to apply: `major`, `minor`, or `patch`
- `tag-prefix`
  Prefix for generated tags, default `v`
- `write-tag`
  When `true`, creates and pushes the computed tag to `origin`, retrying if the tag already exists remotely

## Outputs

- `new-tag`: computed next tag (for example `v1.4.2`)
- `previous-tag`: latest existing tag used as the bump source
- `version-bump-used`: resolved bump type actually applied

## Basic Example

```yaml
- name: Bump version tag
  id: bump
  uses: faisal-memon/semver-bump-action@v0.0.9
  with:
    version-bump: ${{ github.event_name == 'workflow_dispatch' && inputs.version_bump || '' }}
    write-tag: "true"
```

## Compute Only (No Tag Push)

```yaml
- name: Compute next version only
  id: bump
  uses: faisal-memon/semver-bump-action@v0.0.9
  with:
    write-tag: "false"
```

## Notes

- Ensure `actions/checkout` uses `fetch-depth: 0` in workflows that depend on tags.
- For repositories with concurrent release jobs, keep `write-tag: "true"` to use built-in retry-safe tag writes.
