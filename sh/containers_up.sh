#!/bin/bash -Eeu
readonly ROOT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd )"
source "${ROOT_DIR}/sh/wait_until_ready_and_clean.sh"

# - - - - - - - - - - - - - - - - - - - -
service_up()
{
  local -r name="${1}"
  echo
  docker-compose \
    --file "${ROOT_DIR}/docker-compose.yml" \
    up \
    -d \
    --force-recreate \
    "${name}"
}

# - - - - - - - - - - - - - - - - - - - -
containers_up()
{
  service_up runner-server
  wait_until_ready_and_clean test-runner-server "${CYBER_DOJO_RUNNER_PORT}"
  if [ "${1-}" == client ]; then
    service_up runner-client
    #wait_until_ready_and_clean test-runner-client "${CYBER_DOJO_RUNNER_CLIENT_PORT}"
  fi
}

# - - - - - - - - - - - - - - - - - - - -
containers_up "$@"
