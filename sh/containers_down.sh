#!/bin/bash -Eeu

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly TMP_DIR=$(mktemp -d /tmp/cyber-dojo.runner.XXXXXX)
remove_tmp_dir() { rm -rf "${TMP_DIR}" > /dev/null; }
trap remove_tmp_dir EXIT

docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
  stop

docker logs test-runner-server > "${TMP_DIR}/test-runner-server.docker.log"

echo
grep "Goodbye from this runner-server" "${TMP_DIR}/test-runner-server.docker.log"
echo

docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
  down \
  --remove-orphans \
  --volumes
