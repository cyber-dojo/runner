#!/usr/bin/env bash
set -Ee

repo_root() { git rev-parse --show-toplevel; }
export SH_DIR="$(repo_root)/sh"
readonly TMP_DIR=/tmp
readonly DEMO_FILENAME="${TMP_DIR}/runner_demo.html"
readonly DEMO_URL="file://${DEMO_FILENAME}"

source "${SH_DIR}/build_tagged_images.sh"
source "${SH_DIR}/containers_up_healthy_and_clean.sh"
source "${SH_DIR}/echo_versioner_env_vars.sh"
export $(echo_versioner_env_vars)

run_demo() { docker exec -it test_runner_client ruby /runner/code/demo.rb > "${DEMO_FILENAME}"; }

build_tagged_images
server_up_healthy_and_clean
client_up_healthy_and_clean
run_demo
open "${DEMO_URL}"
