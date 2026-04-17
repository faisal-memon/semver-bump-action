#!/usr/bin/env bash
set -euo pipefail

version_bump="${INPUT_VERSION_BUMP:-}"
default_bump="${INPUT_DEFAULT_BUMP:-patch}"
tag_prefix="${INPUT_TAG_PREFIX:-v}"
commit_message="${INPUT_COMMIT_MESSAGE:-}"
commits_json="${INPUT_COMMITS_JSON:-}"

latest_tag="$(git describe --tags --abbrev=0 2>/dev/null || echo "${tag_prefix}0.0.0")"
latest_tag="${latest_tag#${tag_prefix}}"

IFS='.' read -r major minor patch <<< "${latest_tag}"
major="${major:-0}"
minor="${minor:-0}"
patch="${patch:-0}"

if [[ -z "${version_bump}" ]]; then
  push_messages="${commit_message}"

  if [[ -n "${commits_json}" ]] && command -v jq >/dev/null 2>&1; then
    extra_messages="$(printf '%s' "${commits_json}" | jq -r '.[].message // empty')"
    push_messages="$(printf '%s\n%s' "${push_messages}" "${extra_messages}")"
  fi

  case "${push_messages}" in
    *"[major]"*|*"#major"*)
      version_bump="major"
      ;;
    *"[minor]"*|*"#minor"*)
      version_bump="minor"
      ;;
    *"[patch]"*|*"#patch"*)
      version_bump="patch"
      ;;
    *)
      version_bump="${default_bump}"
      ;;
  esac
fi

case "${version_bump}" in
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  patch)
    patch=$((patch + 1))
    ;;
  *)
    echo "Unsupported version bump: ${version_bump}" >&2
    exit 1
    ;;
esac

new_tag="${tag_prefix}${major}.${minor}.${patch}"
previous_tag="${tag_prefix}${latest_tag}"

{
  echo "new-tag=${new_tag}"
  echo "previous-tag=${previous_tag}"
  echo "version-bump-used=${version_bump}"
} >> "${GITHUB_OUTPUT}"
