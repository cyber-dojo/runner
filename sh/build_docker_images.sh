#!/bin/bash
set -e

readonly ROOT_DIR="$( cd "$( dirname "${0}" )" && cd .. && pwd )"
readonly SHA=$(cd "${ROOT_DIR}" && git rev-parse HEAD)

echo ${SHA} > ${ROOT_DIR}/sha.txt

docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
    build

rm ${ROOT_DIR}/sha.txt
