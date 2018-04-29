#!/bin/bash

readonly ROOT_DIR="$( cd "$( dirname "${0}" )" && cd .. && pwd )"

export SHA=$(git rev-parse HEAD)

docker-compose --file ${ROOT_DIR}/docker-compose.yml build
