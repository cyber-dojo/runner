#!/bin/bash -Ee

readonly ROOT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"

docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
  down \
  --remove-orphans \
  --volumes
