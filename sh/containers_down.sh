#!/bin/bash -Ee

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
  stop

docker logs test-runner-server

echo

docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
  down \
  --remove-orphans \
  --volumes
