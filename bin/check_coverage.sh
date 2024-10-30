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
  local -r TEST_LOG=test.run.log
  local -r HOST_TEST_DIR="${ROOT_DIR}/test/${TYPE}"
  local -r HOST_REPORTS_DIR="${ROOT_DIR}/reports/${TYPE}"  # where report files have been written to
  local -r CONTAINER_TMP_DIR=/tmp                          # where to mount to in container

  exit_non_zero_unless_file_exists "${HOST_REPORTS_DIR}/${TEST_LOG}"
  exit_non_zero_unless_file_exists "${HOST_REPORTS_DIR}/index.html"
  exit_non_zero_unless_file_exists "${HOST_REPORTS_DIR}/summary.json"
  exit_non_zero_unless_file_exists "${HOST_TEST_DIR}/max_metrics.json"

  set +e
  docker run \
    --rm \
    --env CODE_DIR=app \
    --env TEST_DIR=test \
    --volume ${HOST_REPORTS_DIR}/${TEST_LOG}:${CONTAINER_TMP_DIR}/${TEST_LOG}:ro \
    --volume ${HOST_REPORTS_DIR}/summary.json:${CONTAINER_TMP_DIR}/summary.json:ro \
    --volume ${HOST_TEST_DIR}/max_metrics.json:${CONTAINER_TMP_DIR}/max_metrics.json:ro \
    cyberdojo/check-test-metrics:latest \
      "${CONTAINER_TMP_DIR}/${TEST_LOG}" \
      "${CONTAINER_TMP_DIR}/summary.json" \
      "${CONTAINER_TMP_DIR}/max_metrics.json" \
    | tee -a "${HOST_REPORTS_DIR}/${TEST_LOG}"

  local -r STATUS=${PIPESTATUS[0]}
  set -e

  echo "${TYPE} coverage status == ${STATUS}"
  echo
  return "${STATUS}"
}

check_coverage "$@"
