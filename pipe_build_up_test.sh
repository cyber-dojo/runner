#!/bin/bash
set -e

readonly SH_DIR="$( cd "$( dirname "${0}" )" && pwd )/sh"

export SHA=$(cd "${SH_DIR}" && git rev-parse HEAD)

"${SH_DIR}/build_docker_images.sh"
"${SH_DIR}/docker_containers_up.sh"
"${SH_DIR}/tear_down.sh"
if "${SH_DIR}/run_tests_in_containers.sh" "$@"; then
  "${SH_DIR}/docker_containers_down.sh"
fi
