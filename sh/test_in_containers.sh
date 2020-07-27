#!/bin/bash -Eeu
readonly root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly my_name=runner
client_status=0
server_status=0

# - - - - - - - - - - - - - - - - - - - - - - - - - -
main()
{
  if [ "${1:-}" == client ]; then
    shift
    run_client_tests "${@:-}"
  elif [ "${1:-}" == server ]; then
    shift
    run_server_tests "${@:-}"
  else
    run_server_tests "${@:-}"
    run_client_tests "${@:-}"
  fi
  echo
  if [ "${client_status}" == 0 ] && [ "${server_status}" == 0 ]; then
    echo All passed
  else
    exit 42
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
run_client_tests() { run_tests "$(client_user)" client "${@:-}"; }
run_server_tests() { run_tests "$(server_user)" server "${@:-}"; }

# - - - - - - - - - - - - - - - - - - - - - - - - - -
client_user() { echo "${CYBER_DOJO_RUNNER_CLIENT_USER}"; }
server_user() { echo "${CYBER_DOJO_RUNNER_SERVER_USER}"; }

# - - - - - - - - - - - - - - - - - - - - - - - - - -
run_tests()
{
  local -r user="${1}" # eg nobody
  local -r type="${2}" # eg client|server
  local -r container_name="test-${my_name}-${type}" # eg test-runner-server
  local -r coverage_root=/tmp/coverage/${type}      # only /tmp in container is writable
  local -r test_dir="${root_dir}/test"
  local -r coverage_dir=${test_dir}/coverage/${type}
  local -r test_run_log=test.run.log
  local -r coverage_code_tab_name=code
  local -r coverage_test_tab_name=test

  echo
  echo '=================================='
  echo "Running ${type} tests"
  echo '=================================='

  rm -f "${coverage_dir}/${test_run_log}"
  mkdir -p "${test_dir}/coverage"

  set +e
  docker exec \
    --env COVERAGE_CODE_TAB_NAME=${coverage_code_tab_name} \
    --env COVERAGE_TEST_TAB_NAME=${coverage_test_tab_name} \
    --user "${user}" \
    "${container_name}" \
      sh -c "/test/run.sh ${coverage_root} ${test_run_log} ${type} ${*:3}"
  set -e

  # You can't [docker cp] from a tmpfs, so tar-piping coverage out
  docker exec \
    "${container_name}" \
    tar Ccf \
      "$(dirname "${coverage_root}")" \
      - "$(basename "${coverage_root}")" \
        | tar Cxf "${test_dir}/coverage/" -

  set +e
  docker run \
    --env COVERAGE_CODE_TAB_NAME=${coverage_code_tab_name} \
    --env COVERAGE_TEST_TAB_NAME=${coverage_test_tab_name} \
    --rm \
    --volume ${coverage_dir}/${test_run_log}:/app/${test_run_log}:ro \
    --volume ${coverage_dir}/index.html:/app/index.html:ro \
    --volume ${test_dir}/${type}/metrics.rb:/app/metrics.rb:ro \
    cyberdojo/check-test-results:latest \
    sh -c "ruby /app/check_test_results.rb /app/${test_run_log} /app/index.html" \
      | tee -a ${coverage_dir}/${test_run_log}
  local -r status=${PIPESTATUS[0]}
  set -e

  echo "${type} coverage at ${coverage_dir}/index.html"
  echo "${type} status == ${status}"
  if [ "${status}" != '0' ]; then
    echo "${type} log follows..."
    echo
    docker logs "${container_name}"
  fi
  if [ "${type}" == client ]; then
    client_status="${status}"
  fi
  if [ "${type}" == server ]; then
    server_status="${status}"
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
main "$@"
