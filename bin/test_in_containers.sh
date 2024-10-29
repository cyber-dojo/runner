#!/usr/bin/env bash
set -Eeu

repo_root() { git rev-parse --show-toplevel; }

# - - - - - - - - - - - - - - - - - - - - - - - - - -
test_in_containers()
{
  if [ "${1:-}" == 'client' ]; then
    shift
    run_client_tests "${@:-}"
  elif [ "${1:-}" == 'server' ]; then
    shift
    run_server_tests "${@:-}"
  else
    run_server_tests "${@:-}"
    run_client_tests "${@:-}"
  fi
  echo All passed
  echo
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
run_client_tests()
{
  run_tests \
    "${CYBER_DOJO_RUNNER_CLIENT_USER}" \
    "${CYBER_DOJO_RUNNER_CLIENT_CONTAINER_NAME}" \
    client "${@:-}";
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
run_server_tests()
{
  run_tests \
    "${CYBER_DOJO_RUNNER_SERVER_USER}" \
    "${CYBER_DOJO_RUNNER_SERVER_CONTAINER_NAME}" \
    server "${@:-}";
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
run_tests()
{
  local -r USER="${1}"           # eg nobody
  local -r CONTAINER_NAME="${2}" # eg test_runner_server
  local -r TYPE="${3}"           # eg server

  echo
  echo '=================================='
  echo "Running ${TYPE} tests"
  echo '=================================='

  local -r CODE_DIR=code
  local -r TEST_DIR=test
  local -r TEST_LOG=test.run.log

  local -r CONTAINER_COVERAGE_DIR="/tmp/reports" # where tests write to.
                                                # NB fs is read-only, tmpfs at /tmp
                                                # NB run.sh ensures this dir exists
  set +e
  docker exec \
    --env CODE_DIR="${CODE_DIR}" \
    --env TEST_DIR="${TEST_DIR}" \
    --user "${USER}" \
    "${CONTAINER_NAME}" \
      sh -c "/runner/test/lib/run.sh ${CONTAINER_COVERAGE_DIR} ${TEST_LOG} ${TYPE} ${*:4}"
  local -r STATUS=$?
  set -e

  local -r HOST_REPORTS_DIR="${ROOT_DIR}/reports/${TYPE}"  # where to tar-pipe files to

  rm -rf "${HOST_REPORTS_DIR}" &> /dev/null || true
  mkdir -p "${HOST_REPORTS_DIR}" &> /dev/null || true

  docker exec \
    "${CONTAINER_NAME}" \
    tar Ccf "${CONTAINER_COVERAGE_DIR}" - . \
        | tar Cxf "${HOST_REPORTS_DIR}/" -

  # Check we generated expected files.
  #exit_non_zero_unless_file_exists "${HOST_REPORTS_DIR}/${TEST_LOG}"
  #exit_non_zero_unless_file_exists "${HOST_REPORTS_DIR}/coverage/index.html"
  #exit_non_zero_unless_file_exists "${HOST_REPORTS_DIR}/coverage/summary.json"

  echo "${TYPE} test branch-coverage report is at:"
  echo "${HOST_REPORTS_DIR}/coverage/index.html"
  echo
  echo "${TYPE} test status == ${STATUS}"
  echo

  if [ "${STATUS}" != 0 ]; then
    echo Docker logs "${CONTAINER_NAME}"
    echo
    docker logs "${CONTAINER_NAME}" 2>&1
  fi

  return ${STATUS}
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
exit_non_zero_unless_file_exists()
{
  local -r filename="${1}"
  if [ ! -f "${filename}" ]; then
    echo "ERROR: ${filename} does not exist"
    exit 42
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
abs_filename()
{
  echo "$(cd "$(dirname "${1}")" && pwd)/$(basename "${1}")"
}
