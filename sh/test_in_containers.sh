#!/bin/bash -Eeu
readonly root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly my_name=runner
readonly client_user="${1}"; shift
readonly server_user="${1}"; shift
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
run_client_tests() { run_tests "${client_user}" client "${@:-}"; }
run_server_tests() { run_tests "${server_user}" server "${@:-}"; }

# - - - - - - - - - - - - - - - - - - - - - - - - - -
run_tests()
{
  local -r user="${1}" # eg nobody
  local -r type="${2}" # eg client|server
  local -r reports_dir_name=reports
  local -r tmp_dir=/tmp
  local -r coverage_root=/${tmp_dir}/${reports_dir_name}
  local -r test_dir="${root_dir}/test/${type}"
  local -r reports_dir=${test_dir}/${reports_dir_name}
  local -r test_log=test.log
  local -r container_name="test-${my_name}-${type}" # eg test-runner-server
  local -r coverage_code_tab_name=tested
  local -r coverage_test_tab_name=tester

  echo
  echo '=================================='
  echo "Running ${type} tests"
  echo '=================================='

  set +e
  docker exec \
    --env COVERAGE_CODE_TAB_NAME=${coverage_code_tab_name} \
    --env COVERAGE_TEST_TAB_NAME=${coverage_test_tab_name} \
    --user "${user}" \
    "${container_name}" \
      sh -c "/test/run.sh ${coverage_root} ${test_log} ${type} ${*:3}"
  set -e

  # You can't [docker cp] from a tmpfs, so tar-piping coverage out
  docker exec \
    "${container_name}" \
    tar Ccf \
      "$(dirname "${coverage_root}")" \
      - "$(basename "${coverage_root}")" \
        | tar Cxf "${test_dir}/" -

  set +e
  docker run \
    --env COVERAGE_CODE_TAB_NAME=${coverage_code_tab_name} \
    --env COVERAGE_TEST_TAB_NAME=${coverage_test_tab_name} \
    --rm \
    --volume ${reports_dir}/${test_log}:${tmp_dir}/${test_log}:ro \
    --volume ${reports_dir}/index.html:${tmp_dir}/index.html:ro \
    --volume ${test_dir}/metrics.rb:/app/metrics.rb:ro \
    cyberdojo/check-test-results:latest \
    sh -c "ruby /app/check_test_results.rb ${tmp_dir}/${test_log} ${tmp_dir}/index.html" \
      | tee -a ${reports_dir}/${test_log}
  local -r status=${PIPESTATUS[0]}
  set -e

  local -r coverage_path="${reports_dir}/index.html"
  echo "${type} coverage at ${coverage_path}"
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
