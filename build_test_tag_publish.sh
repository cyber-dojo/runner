#!/bin/bash
set -e

if [ "${1}" = '-h' ] || [ "${1}" = '--help' ]; then
  echo
  echo 'Use: build_test_tag_publish.sh [client|server] [ID...]'
  echo 'Options:'
  echo '   client  - only run the tests from inside the client'
  echo '   server  - only run the tests from inside the server'
  echo '   ID...   - only run the tests matching these identifiers'
  exit 0
fi

readonly SH_DIR="$( cd "$( dirname "${0}" )" && pwd )/sh"

source ${SH_DIR}/cat_env_vars.sh
export $(cat_env_vars)
${SH_DIR}/build_docker_images.sh
${SH_DIR}/tear_down.sh
${SH_DIR}/docker_containers_up.sh
${SH_DIR}/on_ci_pull_dependent_images.sh
${SH_DIR}/test_in_containers.sh "$@"
${SH_DIR}/docker_containers_down.sh
${SH_DIR}/tag_image.sh
${SH_DIR}/on_ci_publish_tagged_images.sh
#${SH_DIR}/trigger_dependent_images.sh
