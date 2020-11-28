#!/bin/bash -Eeu

source "${SH_DIR}/wait_until_ready_and_clean.sh"

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
  if [ "${1-}" != server ]; then
    service_up runner-client
    wait_until_ready test-runner-client "${CYBER_DOJO_RUNNER_CLIENT_PORT}"
  fi
}
