#!/bin/bash
set -e

if [ "${1}" = '-h' ] || [ "${1}" = '--help' ]; then
  echo
  echo 'Use: pipe_build_up_test.sh [client|server] [HEX-ID...]'
  echo 'Options:'
  echo '   client  - only run the tests from inside the client'
  echo '   server  - only run the tests from inside the server'
  echo '   HEX-ID  - only run the tests matching this identifier'
  exit 0
fi

readonly SH_DIR="$( cd "$( dirname "${0}" )" && pwd )/sh"

${SH_DIR}/build_docker_images.sh
${SH_DIR}/docker_containers_up.sh
${SH_DIR}/tear_down.sh
if ${SH_DIR}/run_tests_in_containers.sh $@ ; then
  ${SH_DIR}/docker_containers_down.sh
  exit 0
else
  exit 3
fi
