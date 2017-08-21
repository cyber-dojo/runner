#!/bin/bash

readonly MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"

${MY_DIR}/build_docker_image.sh
${MY_DIR}/docker_container_up.sh

#. ${MY_DIR}/../.env

