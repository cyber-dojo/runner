#!/bin/bash
set -e

readonly MY_DIR="$( cd "$( dirname "${0}" )" && pwd )"

${MY_DIR}/build_docker_image.sh
${MY_DIR}/docker_container_up.sh
${MY_DIR}/tear_down.sh
${MY_DIR}/run_tests.sh ${*}
${MY_DIR}/docker_container_down.sh
