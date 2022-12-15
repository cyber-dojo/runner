#!/bin/bash -Ee

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SH_DIR="${ROOT_DIR}/sh"
readonly TMP_DIR=/tmp
readonly DEMO_FILENAME="${TMP_DIR}/runner_demo.html"
readonly DEMO_URL="file://${DEMO_FILENAME}"

source "${SH_DIR}/build_tagged_images.sh"
source "${SH_DIR}/containers_up_healthy_and_clean.sh"
source "${SH_DIR}/echo_versioner_env_vars.sh"
export $(echo_versioner_env_vars)

on_Mac() { [ "$(uname)" == "Darwin" ]; }
run_demo() { docker exec -it test_runner_client ruby /runner/source/demo.rb > "${DEMO_FILENAME}"; }

build_tagged_images
server_up_healthy_and_clean
client_up_healthy_and_clean
run_demo
if on_Mac ; then
  open "${DEMO_URL}"
else
  echo "Demo URL is ${DEMO_URL}"
fi
