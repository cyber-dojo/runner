#!/bin/bash -Ee

readonly ROOT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd )"
source "${ROOT_DIR}/sh/wait_until_ready_and_clean.sh"

# - - - - - - - - - - - - - - - - - - - -
echo
docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
  up \
  -d \
  --force-recreate

wait_until_ready_and_clean test-runner-server "${CYBER_DOJO_RUNNER_PORT}"
wait_until_ready_and_clean test-runner-client "${CYBER_DOJO_RUNNER_CLIENT_PORT}"
