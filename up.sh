#!/bin/bash
set -e

check_up()
{
  set +e
  local s=$(docker ps --filter status=running --format '{{.Names}}' | grep ^${1}$)
  set -e
  if [ "${s}" != "${1}" ]; then
    echo
    echo "${1} exited"
    docker logs ${1}
    exit 1
  fi
}

readonly MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"
docker-compose --file ${MY_DIR}/docker-compose.yml down --volumes
docker-compose --file ${MY_DIR}/docker-compose.yml up -d
# crude wait for services
sleep 1
check_up 'runner_stateless_server'
check_up 'runner_stateless_client'
