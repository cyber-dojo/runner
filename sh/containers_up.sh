#!/bin/bash -Ee

ip_address()
{
  if [ -n "${DOCKER_MACHINE_NAME}" ]; then
    docker-machine ip ${DOCKER_MACHINE_NAME}
  else
    echo localhost
  fi
}

readonly IP_ADDRESS=$(ip_address)

# - - - - - - - - - - - - - - - - - - - -
readonly READY_FILENAME='/tmp/curl-ready-output'

wait_until_ready()
{
  local -r name="${1}"
  local -r port="${2}"
  local -r max_tries=20
  printf "Waiting until ${name} is ready"
  for _ in $(seq ${max_tries})
  do
    if ready ${port} ; then
      printf 'OK\n'
      return
    else
      printf .
      sleep 0.1
    fi
  done
  printf 'FAIL\n'
  echo "${name} not ready after ${max_tries} tries"
  if [ -f "${READY_FILENAME}" ]; then
    cat "${READY_FILENAME}"
  fi
  docker logs ${name}
  exit 42
}

# - - - - - - - - - - - - - - - - - - - -
ready()
{
  local -r port="${1}"
  local -r path=ready?
  local -r curl_cmd="curl --output ${READY_FILENAME} --silent --fail -X GET http://${IP_ADDRESS}:${port}/${path}"
  rm -f "${READY_FILENAME}"
  if ${curl_cmd} && [ "$(cat "${READY_FILENAME}")" = '{"ready?":true}' ]; then
    true
  else
    false
  fi
}

# - - - - - - - - - - - - - - - - - - - -
wait_till_up()
{
  local n=10
  while [ $(( n -= 1 )) -ge 0 ]
  do
    if docker ps --filter status=running --format '{{.Names}}' | grep -q ^${1}$ ; then
      return
    else
      sleep 0.5
    fi
  done
  echo "${1} not up after 5 seconds"
  docker logs "${1}"
  exit 42
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
    stderr "DID _NOT_ FIND WARNING!!: ${known_warning}"
  fi
  echo "${stripped}"
}

# - - - - - - - - - - - - - - - - - - - -
stderr()
{
  >&2 echo "${1}"
}

# - - - - - - - - - - - - - - - - - - - -
warn_if_unclean()
{
  local -r name="${1}"
  local log=$(docker logs "${name}" 2>&1)

  # Thin warnings
  #local -r daemon_warning="daemons-1.3.1(.*)warning\: mismatched indentations at 'rescue'"
  #log=$(strip_known_warning "${log}" "${daemon_warning}")

  # Puma warnings
  local -r last_arg_warning="puma.rb:(.*): warning: (.*) the last argument was passed as a single Hash"
  log=$(strip_known_warning "${log}" "${last_arg_warning}")
  local -r splat_keyword_warning="server.rb:(.*): warning: although a splat keyword arguments here"
  log=$(strip_known_warning "${log}" "${splat_keyword_warning}")

  local -r line_count=$(echo -n "${log}" | grep --count '^')
  echo -n "Checking ${name} started cleanly..."
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
readonly ROOT_DIR="$( cd "$(dirname "${0}")/.." && pwd )"

export NO_PROMETHEUS=true

docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
  up \
  -d \
  --force-recreate

wait_until_ready test-runner-server ${CYBER_DOJO_RUNNER_PORT}
warn_if_unclean  test-runner-server

wait_till_up     test-runner-client
