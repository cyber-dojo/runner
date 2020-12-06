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

  local -r TMP_DIR=/tmp # fs is read-only with tmpfs at /tmp
  local -r TEST_LOG=test.log
  # Remove old copies of files we are about to create
  rm ${TMP_DIR}/${TEST_LOG} 2> /dev/null || true
  rm ${TMP_DIR}/index.html  2> /dev/null || true

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  local -r COVERAGE_CODE_TAB_NAME=tested
  local -r COVERAGE_TEST_TAB_NAME=tester
  local -r REPORTS_DIR_NAME=reports
  local -r COVERAGE_ROOT=/${TMP_DIR}/${REPORTS_DIR_NAME}
  set +e
  docker exec \
    --env COVERAGE_CODE_TAB_NAME=${COVERAGE_CODE_TAB_NAME} \
    --env COVERAGE_TEST_TAB_NAME=${COVERAGE_TEST_TAB_NAME} \
    --user "${USER}" \
    "${CONTAINER_NAME}" \
      sh -c "/test/run.sh ${COVERAGE_ROOT} ${TEST_LOG} ${TYPE} ${*:4}"
  set -e

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  # You can't [docker cp] from a tmpfs, so tar-piping coverage out
  local -r TEST_DIR="${ROOT_DIR}/test/${TYPE}"
  docker exec \
    "${CONTAINER_NAME}" \
    tar Ccf \
      "$(dirname "${COVERAGE_ROOT}")" \
      - "$(basename "${COVERAGE_ROOT}")" \
        | tar Cxf "${TEST_DIR}/" -

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  local -r REPORTS_DIR=${TEST_DIR}/${REPORTS_DIR_NAME}
  set +e
  docker run \
    --env COVERAGE_CODE_TAB_NAME=${COVERAGE_CODE_TAB_NAME} \
    --env COVERAGE_TEST_TAB_NAME=${COVERAGE_TEST_TAB_NAME} \
    --rm \
    --volume ${REPORTS_DIR}/${TEST_LOG}:${TMP_DIR}/${TEST_LOG}:ro \
    --volume ${REPORTS_DIR}/index.html:${TMP_DIR}/index.html:ro \
    --volume ${TEST_DIR}/metrics.rb:/app/metrics.rb:ro \
    cyberdojo/check-test-results:latest \
      sh -c "ruby /app/check_test_results.rb ${TMP_DIR}/${TEST_LOG} ${TMP_DIR}/index.html" \
    | tee -a ${REPORTS_DIR}/${TEST_LOG}
  local -r STATUS=${PIPESTATUS[0]}
  set -e

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
  local -r COVERAGE_PATH="${REPORTS_DIR}/index.html"
  echo "${TYPE} test coverage at ${COVERAGE_PATH}"
  echo "${TYPE} test status == ${STATUS}"
  if [ "${STATUS}" != 0 ]; then
    docker logs "${CONTAINER_NAME}"
  fi
  return ${STATUS}
}
