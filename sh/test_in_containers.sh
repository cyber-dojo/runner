#!/bin/bash -Eeu

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

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Run tests (with coverage) inside the container.

  local -r COVERAGE_CODE_TAB_NAME=tested
  local -r COVERAGE_TEST_TAB_NAME=tester
  local -r CONTAINER_TMP_DIR=/tmp # fs is read-only with tmpfs at /tmp
  local -r CONTAINER_COVERAGE_DIR="/${CONTAINER_TMP_DIR}/reports"
  local -r TEST_LOG=test.log

  # Remove old copies of files we are about to create
  rm "${CONTAINER_TMP_DIR}/${TEST_LOG}" 2> /dev/null || true
  rm "${CONTAINER_TMP_DIR}/index.html"  2> /dev/null || true

  set +e
  docker exec \
    --env COVERAGE_CODE_TAB_NAME="${COVERAGE_CODE_TAB_NAME}" \
    --env COVERAGE_TEST_TAB_NAME="${COVERAGE_TEST_TAB_NAME}" \
    --user "${USER}" \
    "${CONTAINER_NAME}" \
      sh -c "/test/run.sh ${CONTAINER_COVERAGE_DIR} ${TEST_LOG} ${TYPE} ${*:4}"
  set -e

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Extract test-run results and coverage data from the container.
  # You can't [docker cp] from a tmpfs, so tar-piping coverage out.

  if [ "${TYPE}" == server ]; then
    local -r HOST_TEST_DIR="${ROOT_DIR}/test/${TYPE}"
  else
    local -r HOST_TEST_DIR="${ROOT_DIR}/test/${TYPE}"
  fi

  docker exec \
    "${CONTAINER_NAME}" \
    tar Ccf \
      "$(dirname "${CONTAINER_COVERAGE_DIR}")" \
      - "$(basename "${CONTAINER_COVERAGE_DIR}")" \
        | tar Cxf "${HOST_TEST_DIR}/" -

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Process test-run results and coverage data.

  local -r HOST_REPORTS_DIR="${HOST_TEST_DIR}/reports"
  mkdir -p "${HOST_REPORTS_DIR}"
  set +e
  docker run \
    --env COVERAGE_CODE_TAB_NAME="${COVERAGE_CODE_TAB_NAME}" \
    --env COVERAGE_TEST_TAB_NAME="${COVERAGE_TEST_TAB_NAME}" \
    --rm \
    --volume ${HOST_REPORTS_DIR}/${TEST_LOG}:${CONTAINER_TMP_DIR}/${TEST_LOG}:ro \
    --volume ${HOST_REPORTS_DIR}/index.html:${CONTAINER_TMP_DIR}/index.html:ro \
    --volume ${HOST_TEST_DIR}/metrics.rb:/app/metrics.rb:ro \
    cyberdojo/check-test-results:latest \
      sh -c \
        "ruby /app/check_test_results.rb \
          ${CONTAINER_TMP_DIR}/${TEST_LOG} \
          ${CONTAINER_TMP_DIR}/index.html" \
    | tee -a "${HOST_REPORTS_DIR}/${TEST_LOG}"

  local -r STATUS=${PIPESTATUS[0]}
  set -e

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # Tell caller where the coverage files are...

  echo "${TYPE} test coverage at $(abs_filename "${HOST_REPORTS_DIR}/index.html")"
  echo "${TYPE} test status == ${STATUS}"
  if [ "${STATUS}" != 0 ]; then
    echo Docker logs "${CONTAINER_NAME}"
    echo
    docker logs "${CONTAINER_NAME}" 2>&1
  fi
  return ${STATUS}
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
abs_filename()
{
  echo "$(cd "$(dirname "${1}")" && pwd)/$(basename "${1}")"
}
