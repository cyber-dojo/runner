#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${ROOT_DIR}/bin/lib.sh"

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: ${MY_NAME} {server|client}

    Check test coverage (and other metrics) for tests run from inside the client or server container only

EOF
}

check_args()
{
  case "${1:-}" in
    '-h' | '--help')
      show_help
      exit 0
      ;;
    'server' | 'client')
      ;;
    '')
      show_help
      stderr "no argument - must be 'client' or 'server'"
      exit 42
      ;;
    *)
      show_help
      stderr "argument is '${1:-}' - must be 'client' or 'server'"
      exit 42
  esac
}

check_coverage()
{
  check_args "$@"
  local -r TYPE="${1}"           # {server|client}
  local -r TEST_LOG=test.log
  local -r HOST_TEST_DIR="${ROOT_DIR}/test/${TYPE}"
  local -r HOST_REPORTS_DIR="${ROOT_DIR}/reports/${TYPE}"  # where report json files have been written to
  local -r CONTAINER_TMP_DIR=/tmp

  exit_non_zero_unless_file_exists "${HOST_REPORTS_DIR}/test_metrics.json"
  exit_non_zero_unless_file_exists "${HOST_REPORTS_DIR}/coverage_metrics.json"

  set +e
  docker run \
    --rm \
    --entrypoint="" \
    --env COVERAGE_ROOT="${CONTAINER_TMP_DIR}" \
    --env COVERAGE_CODE_TAB_NAME=app \
    --env COVERAGE_TEST_TAB_NAME=test \
    --volume ${HOST_REPORTS_DIR}/test_metrics.json:${CONTAINER_TMP_DIR}/test_metrics.json:ro \
    --volume ${HOST_REPORTS_DIR}/coverage_metrics.json:${CONTAINER_TMP_DIR}/coverage_metrics.json:ro \
    --volume ${HOST_TEST_DIR}/check_test_metrics.rb:${CONTAINER_TMP_DIR}/check_test_metrics.rb:ro \
      cyberdojo/runner:latest \
        sh -c "ruby ${CONTAINER_TMP_DIR}/check_test_metrics.rb"

  local -r STATUS=$?
  set -e

  echo "${TYPE} coverage status == ${STATUS}"
  echo
  return "${STATUS}"
}

check_coverage "$@"
