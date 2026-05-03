#!/usr/bin/env bash
set -euo pipefail

version_bump="${INPUT_VERSION_BUMP:-}"
default_bump="${INPUT_DEFAULT_BUMP:-patch}"
tag_prefix="${INPUT_TAG_PREFIX:-v}"
commit_message="${INPUT_COMMIT_MESSAGE:-}"
commits_json="${INPUT_COMMITS_JSON:-}"
write_tag="${INPUT_WRITE_TAG:-false}"
max_push_retries="${INPUT_MAX_PUSH_RETRIES:-5}"
retry_sleep_seconds="${INPUT_RETRY_SLEEP_SECONDS:-1}"

compute_version_bump() {
  if [[ -n "${version_bump}" ]]; then
    printf '%s\n' "${version_bump}"
    return
  fi

  push_messages="${commit_message}"

  if [[ -n "${commits_json}" ]] && command -v jq >/dev/null 2>&1; then
    extra_messages="$(printf '%s' "${commits_json}" | jq -r '.[].message // empty')"
    push_messages="$(printf '%s\n%s' "${push_messages}" "${extra_messages}")"
  fi

  case "${push_messages}" in
    *"[major]"*|*"#major"*)
      printf '%s\n' "major"
      ;;
    *"[minor]"*|*"#minor"*)
      printf '%s\n' "minor"
      ;;
    *"[patch]"*|*"#patch"*)
      printf '%s\n' "patch"
      ;;
    *)
      printf '%s\n' "${default_bump}"
      ;;
  esac
}

bump_from_previous() {
  local previous_version="$1"
  local bump_type="$2"
  local major minor patch
  IFS='.' read -r major minor patch <<< "${previous_version}"
  major="${major:-0}"
  minor="${minor:-0}"
  patch="${patch:-0}"

  case "${bump_type}" in
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
      echo "Unsupported version bump: ${bump_type}" >&2
      exit 1
      ;;
  esac

  printf '%s\n' "${major}.${minor}.${patch}"
}

version_bump="$(compute_version_bump)"
previous_tag=""
new_tag=""

if [[ "${write_tag}" == "true" ]]; then
  push_err_file="$(mktemp)"
  trap 'rm -f "${push_err_file}"' EXIT

  for ((attempt = 1; attempt <= max_push_retries; attempt++)); do
    git fetch --tags --force >/dev/null 2>&1 || true

    latest_tag="$(git describe --tags --abbrev=0 2>/dev/null || echo "${tag_prefix}0.0.0")"
    latest_tag="${latest_tag#"${tag_prefix}"}"
    previous_tag="${tag_prefix}${latest_tag}"
    next_version="$(bump_from_previous "${latest_tag}" "${version_bump}")"
    new_tag="${tag_prefix}${next_version}"

    if git rev-parse -q --verify "refs/tags/${new_tag}" >/dev/null 2>&1; then
      git tag -d "${new_tag}" >/dev/null 2>&1 || true
    fi

    git tag "${new_tag}"

    if git push origin "refs/tags/${new_tag}" >"${push_err_file}" 2>&1; then
      break
    fi

    push_err="$(cat "${push_err_file}")"
    git tag -d "${new_tag}" >/dev/null 2>&1 || true

    if [[ "${push_err}" == *"already exists"* ]] && [[ "${attempt}" -lt "${max_push_retries}" ]]; then
      sleep "${retry_sleep_seconds}"
      continue
    fi

    echo "${push_err}" >&2
    exit 1
  done
else
  latest_tag="$(git describe --tags --abbrev=0 2>/dev/null || echo "${tag_prefix}0.0.0")"
  latest_tag="${latest_tag#"${tag_prefix}"}"
  previous_tag="${tag_prefix}${latest_tag}"
  next_version="$(bump_from_previous "${latest_tag}" "${version_bump}")"
  new_tag="${tag_prefix}${next_version}"
fi

{
  echo "new-tag=${new_tag}"
  echo "previous-tag=${previous_tag}"
  echo "version-bump-used=${version_bump}"
} >> "${GITHUB_OUTPUT}"
