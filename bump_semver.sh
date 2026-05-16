#!/usr/bin/env bash
set -euo pipefail

version_bump="${INPUT_VERSION_BUMP:-}"
tag_prefix="${INPUT_TAG_PREFIX:-v}"
github_token="${INPUT_GITHUB_TOKEN:-${GITHUB_TOKEN:-}}"
write_tag="${INPUT_WRITE_TAG:-false}"
write_major_tag="${INPUT_WRITE_MAJOR_TAG:-false}"

main() {
  version_bump="$(compute_version_bump)"
  previous_tag=""
  new_tag=""
  git fetch --tags --force >/dev/null 2>&1 || true
  latest_tag="$(git describe --tags --abbrev=0 2>/dev/null || echo "${tag_prefix}0.0.0")"
  latest_tag="${latest_tag#"${tag_prefix}"}"
  validate_latest_tag_format "${latest_tag}"
  previous_tag="${tag_prefix}${latest_tag}"
  next_version="$(bump_from_previous "${latest_tag}" "${version_bump}")"
  new_tag="${tag_prefix}${next_version}"
  log_info "Resolved bump=${version_bump} from previous=${previous_tag} to new=${new_tag}"

  if [[ "${write_tag}" == "true" ]]; then
    log_info "write-tag=true; creating and pushing ${new_tag}"
    push_err_file="$(mktemp)"
    trap 'rm -f "${push_err_file}"' EXIT

    if git rev-parse -q --verify "refs/tags/${new_tag}" >/dev/null 2>&1; then
      git tag -d "${new_tag}" >/dev/null 2>&1 || true
    fi

    git tag "${new_tag}"

    if ! git push origin "refs/tags/${new_tag}" >"${push_err_file}" 2>&1; then
      push_err="$(cat "${push_err_file}")"
      git tag -d "${new_tag}" >/dev/null 2>&1 || true
      if [[ "${push_err}" == *"already exists"* ]]; then
        echo "Tag collision for ${new_tag}. Enable workflow concurrency (cancel-in-progress: false) and rerun." >&2
        echo "${push_err}" >&2
        exit 1
      fi
      echo "${push_err}" >&2
      exit 1
    fi

    if [[ "${write_major_tag}" == "true" ]]; then
      major_tag="${tag_prefix}${next_version%%.*}"
      log_info "write-major-tag=true; updating floating major tag ${major_tag}"
      git tag -f "${major_tag}" >/dev/null 2>&1 || true
      if ! git push -f origin "refs/tags/${major_tag}" >"${push_err_file}" 2>&1; then
        cat "${push_err_file}" >&2
        exit 1
      fi
    fi
  fi

  {
    echo "new-tag=${new_tag}"
    echo "previous-tag=${previous_tag}"
    echo "version-bump-used=${version_bump}"
  } >> "${GITHUB_OUTPUT}"
  log_info "Wrote outputs new-tag=${new_tag} previous-tag=${previous_tag} version-bump-used=${version_bump}"
}

log_info() {
  echo "[simple-semver] $*"
}

resolve_version_bump_from_pr_labels() {
  if ! validate_label_resolution_prereqs; then
    return 2
  fi

  local owner repo target_branch api_url pulls_json selected_pr_number labels label_matches
  owner="${GITHUB_REPOSITORY%%/*}"
  repo="${GITHUB_REPOSITORY#*/}"
  api_url="${GITHUB_API_URL:-https://api.github.com}"

  target_branch="${GITHUB_REF_NAME:-}"

  if ! pulls_json="$(curl \
    -fsSL \
    -H "Authorization: Bearer ${github_token}" \
    -H "Accept: application/vnd.github+json" \
    "${api_url}/repos/${owner}/${repo}/commits/${GITHUB_SHA}/pulls"
  )"; then
    echo "Failed to query pull requests for commit ${GITHUB_SHA}." >&2
    return 2
  fi

  selected_pr_number="$(printf '%s' "${pulls_json}" | jq -r --arg b "${target_branch}" '[.[] | select(.base.ref == $b)][0].number // empty')"
  if [[ -z "${selected_pr_number}" ]]; then
    return 1
  fi

  labels="$(printf '%s' "${pulls_json}" | jq -r --arg b "${target_branch}" '[.[] | select(.base.ref == $b)][0].labels[]?.name // empty')"
  label_matches="$(printf '%s\n' "${labels}" | grep -E '^(major|minor|patch)$' || true)"

  local count
  count="$(printf '%s\n' "${label_matches}" | sed '/^$/d' | wc -l | tr -d ' ')"

  if [[ "${count}" -gt 1 ]]; then
    echo "Multiple version labels found on PR #${selected_pr_number}. Use only one of major/minor/patch." >&2
    exit 1
  fi

  if [[ "${count}" -eq 1 ]]; then
    printf '%s\n' "${label_matches}"
    return 0
  fi

  return 1
}

validate_label_resolution_prereqs() {
  if [[ -z "${github_token}" ]]; then
    echo "github-token (or GITHUB_TOKEN) is required when version-bump is empty." >&2
    return 1
  fi

  if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required to resolve version bump from PR labels." >&2
    return 1
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl is required to resolve version bump from PR labels." >&2
    return 1
  fi

  if [[ -z "${GITHUB_EVENT_PATH:-}" ]] || [[ ! -f "${GITHUB_EVENT_PATH}" ]]; then
    echo "GITHUB_EVENT_PATH is required to resolve version bump from PR labels." >&2
    return 1
  fi

  if [[ -z "${GITHUB_REPOSITORY:-}" ]] || [[ -z "${GITHUB_SHA:-}" ]]; then
    echo "GITHUB_REPOSITORY and GITHUB_SHA are required to resolve version bump from PR labels." >&2
    return 1
  fi

  if [[ -z "${GITHUB_REF_NAME:-}" ]]; then
    echo "GITHUB_REF_NAME is required to resolve version bump from PR labels." >&2
    return 1
  fi
}

compute_version_bump() {
  if [[ -n "${version_bump}" ]]; then
    printf '%s\n' "${version_bump}"
    return
  fi

  if resolved_bump="$(resolve_version_bump_from_pr_labels)"; then
    printf '%s\n' "${resolved_bump}"
    return
  else
    status=$?
    if [[ "${status}" -eq 2 ]]; then
      exit 1
    fi
  fi

  printf '%s\n' "patch"
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

validate_latest_tag_format() {
  local latest="$1"
  if [[ ! "${latest}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Latest tag must be semantic version format ${tag_prefix}X.Y.Z, but got ${tag_prefix}${latest}. Fix tags or set an explicit version-bump." >&2
    exit 1
  fi
}

main "$@"
