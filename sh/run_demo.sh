#!/bin/bash

readonly MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"

"${MY_DIR}/build_docker_images.sh"
"${MY_DIR}/docker_containers_up.sh"

. "${MY_DIR}/../.env"

echo "demo is on port=${CYBER_DOJO_RUNNER_CLIENT_PORT}"
