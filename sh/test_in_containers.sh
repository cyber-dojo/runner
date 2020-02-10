#!/bin/bash -Ee

readonly root_dir="$( cd "$( dirname "${0}" )/.." && pwd )"
readonly my_name=runner

# - - - - - - - - - - - - - - - - - - - - - - - - - -
run_tests()
{
  local -r user="${1}" # eg nobody
  local -r type="${2}" # eg client|server
  local -r reports_dir=reports
  local -r coverage_root=/tmp/${reports_dir}
  local -r test_log=test.log
  local -r container_name="test-${my_name}-${type}" # eg test-ragger-server

  echo '=================================='
  echo "Running ${type} tests"
  echo '=================================='

  set +e
  docker exec \
    --user "${user}" \
    "${container_name}" \
      sh -c "/test/run.sh ${coverage_root} ${test_log} ${type} ${*:3}"
  set -e

  # You can't [docker cp] from a tmpfs, so tar-piping coverage out...
  local -r test_dir="${root_dir}/test/${type}" # ...to this dir
  docker exec \
    "${container_name}" \
    tar Ccf \
      "$(dirname "${coverage_root}")" \
      - "$(basename "${coverage_root}")" \
        | tar Cxf "${test_dir}/" -

  set +e
  local -r data_dir=/tmp
  docker run --rm \
    --volume ${test_dir}/${reports_dir}:${data_dir}:ro \
    --volume ${test_dir}/metrics.rb:/app/metrics.rb:ro \
    cyberdojo/check-test-results:latest \
    sh -c "ruby /app/check_test_results.rb ${data_dir}/${test_log} ${data_dir}/index.html" \
      | tee -a ${test_dir}/${reports_dir}/${test_log}
  local -r status=${PIPESTATUS[0]}
  set -e

  echo "Test files copied to test/${type}/${reports_dir}/"
  echo "${type} test status == ${status}"
  if [ "${status}" != '0' ]; then
    docker logs "${container_name}"
  fi
  return ${status}
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
run_server_tests() { run_tests root   server "${@}"; }
run_client_tests() { run_tests nobody client "${@}"; }

# - - - - - - - - - - - - - - - - - - - - - - - - - -
echo
if [ "${1}" == 'server' ]; then
  shift
  run_server_tests "${@}"
elif [ "${1}" == 'client' ]; then
  shift
  run_client_tests "${@}"
else
  run_server_tests "${@}"
  run_client_tests "${@}"
fi
echo All passed
