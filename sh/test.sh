#!/usr/bin/env bash
set -Eeu

repo_root() { git rev-parse --show-toplevel; }
export SH_DIR="$(repo_root)/sh"

source "${SH_DIR}/containers_down.sh"
source "${SH_DIR}/containers_up_healthy_and_clean.sh"
source "${SH_DIR}/create_test_data_manifests_file.sh"
source "${SH_DIR}/remove_zombie_containers.sh"
source "${SH_DIR}/setup_dependent_images.sh"
source "${SH_DIR}/test_in_containers.sh"

source "${SH_DIR}/echo_versioner_env_vars.sh"
export $(echo_versioner_env_vars)

remove_zombie_containers
containers_down
setup_dependent_images "$@"
create_test_data_manifests_file
server_up_healthy_and_clean
client_up_healthy_and_clean "$@"
test_in_containers "$@"
containers_down
