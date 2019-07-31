#!/bin/bash

readonly SH_DIR="$( cd "$( dirname "${0}" )" && pwd )"

"${SH_DIR}/build_docker_images.sh"
"${SH_DIR}/docker_containers_up.sh"

if [ ! -z "${DOCKER_MACHINE_NAME}" ]; then
  declare ip=$(docker-machine ip "${DOCKER_MACHINE_NAME}")
else
  declare ip=localhost
fi

open "http://${ip}:4598"
