#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"

# Removes the directory holding the clone. Armed once TMP_DIR names one.
remove_tmp_dir() { rm -rf "${TMP_DIR}" > /dev/null; }

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: bin/${MY_NAME} <TAG>@<URL>

    Runs one cyber-dojo-start-points repo's run_tests.sh against the runner
    image built from this repo, checking its start_point files go red, amber
    and green.

    <TAG>@<URL> is one line of the git_repo_urls.tagged file in
    https://github.com/cyber-dojo/languages-start-points
    The URL is cloned and the TAG commit checked out, so the start-point is
    tested at the commit that file pins rather than at its HEAD.

    run_tests.sh curls red_amber_green_test.sh, which starts its runner as
    \${CYBER_DOJO_RUNNER_IMAGE}:\${CYBER_DOJO_RUNNER_TAG} read from
    cyberdojo/versioner:latest. bin/build_fake_versioner_image.sh stubs that
    image first, which is what makes the runner under test this repo's build.

    Options:
      -h    Show this help

    Example:
      bin/${MY_NAME} b61527f@https://github.com/cyber-dojo-start-points/java-junit

EOF
}

check_args()
{
  case "${1:-}" in
    '-h' | '--help')
      show_help
      exit 0
      ;;
    '')
      show_help
      stderr "no argument - must be <TAG>@<URL>"
      exit_non_zero
      ;;
  esac
  if [[ "${1}" != *@* ]]; then
    show_help
    stderr "argument is '${1}' - must be <TAG>@<URL>"
    exit_non_zero
  fi
}

# Echoes the <TAG> of a <TAG>@<URL> argument, eg b61527f
tagged_url_tag()
{
  local -r tagged_url="${1}"
  echo "${tagged_url%%@*}"
}

# Echoes the <URL> of a <TAG>@<URL> argument. The URL keeps any later @
# because only the first one separates the tag.
tagged_url_url()
{
  local -r tagged_url="${1}"
  echo "${tagged_url#*@}"
}

# Clones ${url} into ${TMP_DIR} at ${tag} and echoes the directory holding it.
# The clone is unshallow because ${tag} is usually behind the default branch.
clone_start_point()
{
  local -r url="${1}"
  local -r tag="${2}"
  local -r repo_dir="${TMP_DIR}/$(basename "${url}")"
  >&2 echo "Cloning ${url}"
  git clone --quiet "${url}" "${repo_dir}"
  >&2 echo "Checking out ${tag}"
  git -C "${repo_dir}" checkout --quiet "${tag}"
  echo "${repo_dir}"
}

test_one_start_point()
{
  check_args "$@"
  exit_non_zero_unless_installed docker git jq

  # Assigned on its own line so a failing mktemp ends the script. Declaring it
  # readonly in the same statement would return the status of the declaration,
  # leaving TMP_DIR empty and the clone below writing to the filesystem root.
  TMP_DIR="$(mktemp -d /tmp/cyber-dojo-runner-start-point.XXXXXX)"
  readonly TMP_DIR
  trap remove_tmp_dir INT EXIT

  local -r tagged_url="${1}"
  local -r tag="$(tagged_url_tag "${tagged_url}")"
  local -r url="$(tagged_url_url "${tagged_url}")"

  "${ROOT_DIR}/bin/build_fake_versioner_image.sh"

  local -r repo_dir="$(clone_start_point "${url}" "${tag}")"
  exit_non_zero_unless_file_exists "${repo_dir}/run_tests.sh"

  # A cold container on a shared CI machine takes longer to answer its
  # readiness check than the shared script's default of 20 tries allows.
  export CYBER_DOJO_START_POINT_READY_TRIES=50

  echo "Testing ${tagged_url}"
  "${repo_dir}/run_tests.sh"
}

test_one_start_point "$@"
