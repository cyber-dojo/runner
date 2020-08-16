#!/bin/bash -Ee

readonly SH_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly TMP_DIR=$(mktemp -d /tmp/cyber-dojo.runner.demo.XXXXXX)
remove_tmp_dir() { rm -rf "${TMP_DIR}" > /dev/null; }
trap remove_tmp_dir EXIT

source ${SH_DIR}/versioner_env_vars.sh
export $(versioner_env_vars)

"${SH_DIR}/build_tagged_images.sh"
"${SH_DIR}/containers_up.sh"

docker exec -it test-runner-client ruby /app/code/demo.rb > "${TMP_DIR}/runner_demo.html"
open "file://${TMP_DIR}/runner_demo.html"
sleep 3 # allow browser to read file before trap removes its dir
