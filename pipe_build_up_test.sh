#!/bin/bash
set -e

readonly SH_DIR="$( cd "$( dirname "${0}" )" && pwd )/sh"

echo
echo 'Use: pipe_build_up_test.sh [client|server] [HEX-ID...]'
echo 'Options:'
echo '   client  - only run the tests from inside the client'
echo '   server  - only run the tests from inside the server'
echo '   HEX-ID  - only run the tests matching this identifier'

"${SH_DIR}/build_docker_images.sh"
"${SH_DIR}/docker_containers_up.sh"
"${SH_DIR}/tear_down.sh"
"${SH_DIR}/run_tests_in_containers.sh" "$@"
"${SH_DIR}/docker_containers_down.sh"
