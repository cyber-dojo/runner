#!/bin/bash -Ee

readonly ROOT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd )"
readonly TMP_DIR=$(mktemp -d ~/tmp.cyber-dojo.runner.-dir.XXXXXX)
remove_tmp_dir() { rm -rf "${TMP_DIR}" > /dev/null; }
trap remove_tmp_dir EXIT

# - - - - - - - - - - - - - - - - - - - -
ip_address()
{
  if [ -n "${DOCKER_MACHINE_NAME}" ]; then
    docker-machine ip ${DOCKER_MACHINE_NAME}
  else
    echo localhost
  fi
}

# - - - - - - - - - - - - - - - - - - - -
wait_until_ready_and_clean()
{
  local -r name="${1}"
  local -r port="${2}"
  local -r max_tries=20
  echo
  printf "Waiting until ${name} is ready"
  for _ in $(seq ${max_tries})
  do
    if ready ${port} ; then
      printf '.OK\n'
      exit_if_unclean "${name}"
      return
    else
      printf .
      sleep 0.1
    fi
  done
  printf 'FAIL\n'
  echo "${name} not ready after ${max_tries} tries"
  if [ -f "$(ready_filename)" ]; then
    cat "$(ready_filename)"
  fi
  docker logs ${name}
  exit 42
}

# - - - - - - - - - - - - - - - - - - - -
ready()
{
  local -r port="${1}"
  local -r path=ready?
  local -r curl_cmd="curl --output $(ready_filename) --silent --fail -X GET http://$(ip_address):${port}/${path}"
  rm -f "$(ready_filename)"
  if ${curl_cmd} && [ "$(cat "$(ready_filename)")" = '{"ready?":true}' ]; then
    true
  else
    false
  fi
}

# - - - - - - - - - - - - - - - - - - - -
ready_filename()
{
  echo "${TMP_DIR}/curl.ready.output"
}

# - - - - - - - - - - - - - - - - - - - -
exit_if_unclean()
{
  local -r name="${1}"
  local log=$(docker logs "${name}" 2>&1)

  # Example of old known warnings
  #local -r last_arg_warning="puma.rb:(.*): warning: (.*) the last argument was passed as a single Hash"
  #log=$(strip_known_warning "${log}" "${last_arg_warning}")

  local -r line_count=$(echo -n "${log}" | grep --count '^')
  echo -n "Checking ${name} started cleanly."
  # Thin=3, Unicorn=6, Puma=6
  if [ "${line_count}" == '6' ]; then
    echo OK
  else
    echo FAIL
    echo_docker_log "${name}" "${log}"
    exit 42
  fi
}

# - - - - - - - - - - - - - - - - - - - -
strip_known_warning()
{
  local -r log="${1}"
  local -r pattern="${2}"
  local -r warning=$(printf "${log}" | grep --extended-regexp "${pattern}")
  local -r stripped=$(printf "${log}" | grep --invert-match --extended-regexp "${pattern}")
  if [ "${log}" != "${stripped}" ]; then
    stderr "SERVICE START-UP WARNING: ${warning}"
  else
    stderr "DID _NOT_ FIND WARNING!!: ${pattern}"
  fi
  echo "${stripped}"
}

# - - - - - - - - - - - - - - - - - - - -
echo_docker_log()
{
  local -r name="${1}"
  local -r log="${2}"
  echo "[docker logs ${name}]"
  echo "<docker_log>"
  echo "${log}"
  echo "</docker_log>"
}

# - - - - - - - - - - - - - - - - - - - -
stderr()
{
  >&2 echo "${1}"
}

# - - - - - - - - - - - - - - - - - - - -
docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
  up \
  -d \
  --force-recreate

wait_until_ready_and_clean test-runner-server "${CYBER_DOJO_RUNNER_PORT}"
wait_until_ready_and_clean test-runner-client "${CYBER_DOJO_RUNNER_CLIENT_PORT}"
