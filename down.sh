#!/bin/bash

readonly MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"
docker-compose --file ${MY_DIR}/docker-compose.yml down --volumes
