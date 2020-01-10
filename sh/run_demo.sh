#!/bin/bash -Ee

ip_address()
{
  if [ -n "${DOCKER_MACHINE_NAME}" ]; then
    echo "$(docker-machine ip "${DOCKER_MACHINE_NAME}")"
  else
    echo localhost
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - -
readonly SH_DIR="$( cd "$( dirname "${0}" )" && pwd )"
source ${SH_DIR}/versioner_env_vars.sh
export $(versioner_env_vars)
"${SH_DIR}/build_docker_images.sh"
"${SH_DIR}/docker_containers_up.sh"
open "http://$(ip_address):${CYBER_DOJO_RUNNER_DEMO_PORT}"
