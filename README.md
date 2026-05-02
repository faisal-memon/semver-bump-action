# semver-bump-action

Reusable GitHub composite action that computes the next semantic version tag from:

- the latest existing git tag
- an explicit bump input
- or commit-message markers like `[major]`, `[minor]`, `[patch]`

This action preserves the versioning behavior used in `casd`, with one added safety improvement: repositories with no prior tags fall back to `v0.0.0` before applying the selected bump.

## Inputs

- `version-bump`
  Explicit bump to apply: `major`, `minor`, or `patch`
- `default-bump`
  Fallback bump when no explicit bump or commit-message hint is present
- `tag-prefix`
  Prefix for generated tags, default `v`
- `commit-message`
  Primary commit message to inspect for bump hints
- `commits-json`
  JSON array of commits to inspect for bump hints
- `write-tag`
  When `true`, creates and pushes the computed tag to `origin`, retrying if the tag already exists remotely
- `max-push-retries`
  Max attempts for push collisions when `write-tag` is `true` (default `5`)
- `retry-sleep-seconds`
  Delay between collision retries in seconds (default `1`)

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
    commit-message: ${{ github.event.head_commit.message || '' }}
    commits-json: ${{ toJson(github.event.commits) }}
    write-tag: "true"
    max-push-retries: "10"
    retry-sleep-seconds: "1"
```
