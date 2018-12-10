#!/bin/bash
set -e

readonly ROOT_DIR="$( cd "$( dirname "${0}" )" && pwd )"
readonly MY_NAME=runner-stateless
readonly SH_DIR="${ROOT_DIR}/sh"

"${SH_DIR}/build_docker_images.sh"
"${SH_DIR}/docker_containers_up.sh"
"${SH_DIR}/tear_down.sh"
if "${SH_DIR}/run_tests_in_containers.sh" "$@"; then
  "${SH_DIR}/docker_containers_down.sh"
  docker rmi "cyberdojo/${MY_NAME}-client" > /dev/null 2>&1
  docker image prune --force > /dev/null 2>&1
fi
