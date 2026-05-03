# AGENTS.md

## Purpose

`semver-bump-action` is a reusable GitHub composite action that computes the next semantic version tag based on:

- the latest existing Git tag
- an explicit bump input (`major`, `minor`, `patch`)
- or commit-message hints (`[major]`, `[minor]`, `[patch]`, and `#major/#minor/#patch`)

When no prior tags exist, it treats the baseline as `v0.0.0` (or `<tag-prefix>0.0.0`) and bumps from there.

## Core Behavior

The action runs `bump_semver.sh` and emits:

- `new-tag`: the computed next version tag
- `previous-tag`: the latest version tag used as the bump source
- `version-bump-used`: the resolved bump type actually applied

By default, it computes outputs only.

## Retry-Safe Tag Writing

To support concurrent pipelines safely, the action includes an optional optimistic-concurrency write mode.

Enable with:

- `write-tag: "true"`

Optional controls:

- `max-push-retries` (default: `5`)
- `retry-sleep-seconds` (default: `1`)

### Retry flow

When `write-tag` is enabled, each attempt does:

1. `git fetch --tags --force`
2. Read current latest tag from Git
3. Compute next semver using the resolved bump type
4. Create the candidate local tag
5. Push tag to `origin`

If push fails because the tag already exists remotely, the action:

- removes the local tag for that failed attempt
- sleeps for `retry-sleep-seconds`
- re-fetches and recomputes from the new latest tag
- retries until success or `max-push-retries` is reached

If retries are exhausted (or failure is not a tag-collision case), the action exits non-zero with the Git push error output.

## Why this exists

Without this loop, two workflows running close together can both compute the same next version (for example `v1.2.4`) and then conflict on push. The retry loop makes the second writer rebase its version decision on the latest remote tag and publish the next available version instead.

## Maintainer Notes

- `Makefile` is the local developer entry point for linting.
- `make lint` runs ShellCheck and auto-installs the pinned ShellCheck version into `.tools/shellcheck/` when needed.
- `.tools/` is intentionally git-ignored.
- CI pull request linting runs via `.github/workflows/pr_build.yaml`.

## Release Workflow Guardrails

- `.github/workflows/release_build.yaml` is the self-release workflow for this repo.
- It intentionally uses this action itself (`uses: faisal-memon/semver-bump-action@...`) to dogfood behavior.
- It skips release execution for self-version-bump churn commits by checking commit message content.
- It also ignores push events that only modify `AGENTS.md`, so documentation-only agent guidance updates do not create releases.

## Practical Guidance For Future Agents

- Keep changes small and explicit in `bump_semver.sh`; shell behavior can be subtle.
- Run `make lint` after shell edits.
- Preserve backwards compatibility for action inputs when possible; prefer adding optional inputs over changing defaults abruptly.
- When editing release behavior, avoid introducing infinite release loops (self-bump and dependency-bump feedback cycles).
