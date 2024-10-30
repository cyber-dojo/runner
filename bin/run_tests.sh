#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

readonly BIN_DIR="${ROOT_DIR}/bin"

source "${BIN_DIR}/lib.sh"
source "${BIN_DIR}/containers_up_healthy_and_clean.sh"
source "${BIN_DIR}/create_test_data_manifests_file.sh"
source "${BIN_DIR}/setup_dependent_images.sh"
source "${BIN_DIR}/test_in_containers.sh"

source "${BIN_DIR}/echo_versioner_env_vars.sh"
export $(echo_versioner_env_vars)

containers_down
setup_dependent_images "$@"
create_test_data_manifests_file
server_up_healthy_and_clean
client_up_healthy_and_clean "$@"
test_in_containers "$@"
containers_down
