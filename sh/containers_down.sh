#!/bin/bash -Eeu

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo
docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
  stop

sleep 1
echo
docker logs test-runner-client 2>&1 | grep "Goodbye from runner client"
docker logs test-runner-server 2>&1 | grep "Goodbye from runner server"
echo

docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
  down \
  --remove-orphans \
  --volumes
