# semver-bump-action

Reusable GitHub composite action that computes the next semantic version tag from:

- the latest existing git tag
- an explicit bump input
- or commit-message markers like `[major]`, `[minor]`, `[patch]`

This action preserves the versioning behavior used in `casd`, with one added safety improvement: repositories with no prior tags fall back to `v0.0.0` before applying the selected bump.

## Inputs

- `version-bump`
  Explicit bump to apply: `major`, `minor`, or `patch`
- `tag-prefix`
  Prefix for generated tags, default `v`
- `write-tag`
  When `true`, creates and pushes the computed tag to `origin`, retrying if the tag already exists remotely

## Outputs

- `new-tag`
- `previous-tag`
- `version-bump-used`

## Example

```yaml
- name: Bump version tag
  id: bump
  uses: faisal-memon/semver-bump-action@main
  with:
    version-bump: ${{ github.event_name == 'workflow_dispatch' && inputs.version_bump || '' }}
    write-tag: "true"
```
