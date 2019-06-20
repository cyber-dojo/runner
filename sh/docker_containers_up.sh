#!/bin/bash
set -e

wait_until_ready()
{
  local name="${1}"
  local port="${2}"
  local max_tries=20
  local cmd="curl --fail --data '{}' -X GET http://localhost:${port}/ready?"
  #local cmd="curl --silent --fail --data '{}' -X GET http://localhost:${port}/ready?"
  #cmd+=" > /dev/null 2>&1"

  echo "DOCKER_MACHINE_COMMAND=:${DOCKER_MACHINE_COMMAND}:"
  if [ -n ${DOCKER_MACHINE_NAME} ]; then
    cmd="docker-machine ssh ${DOCKER_MACHINE_NAME} ${cmd}"
  fi
  echo -n "Waiting until ${name} is ready"
  for _ in $(seq ${max_tries})
  do
    echo -n '.'
    if eval ${cmd} ; then
      echo 'OK'
      return
    else
      sleep 0.1
    fi
  done
  echo 'FAIL'
  echo "${name} not ready after ${max_tries} tries"
  docker logs ${name}
  exit 1
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
  exit 1
}

# - - - - - - - - - - - - - - - - - - - -

exit_unless_clean()
{
  local name="${1}"
  local docker_logs=$(docker logs "${name}")
  echo -n "Checking ${name} started cleanly..."
  if [[ -z "${docker_logs}" ]]; then
    echo 'OK'
  else
    echo 'FAIL'
    echo "[docker logs] not empty on startup"
    echo "<docker_log>"
    echo "${docker_logs}"
    echo "</docker_log>"
    exit 1
  fi
}

# - - - - - - - - - - - - - - - - - - - -

readonly ROOT_DIR="$( cd "$( dirname "${0}" )" && cd .. && pwd )"

echo
docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
  up \
  -d \
  --force-recreate

readonly MY_NAME=runner

wait_until_ready  "test-${MY_NAME}-server" 4597
exit_unless_clean "test-${MY_NAME}-server"

wait_till_up "test-${MY_NAME}-client"
