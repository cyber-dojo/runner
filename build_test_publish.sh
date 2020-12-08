#!/bin/bash -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SH_DIR="${ROOT_DIR}/scripts"

source "${SH_DIR}/build_tagged_images.sh"
source "${SH_DIR}/containers_down.sh"
source "${SH_DIR}/containers_up_healthy_and_clean.sh"
source "${SH_DIR}/create_test_data_manifests_file.sh"
source "${SH_DIR}/exit_zero_if_build_only.sh"
source "${SH_DIR}/exit_zero_if_show_help.sh"
source "${SH_DIR}/exit_non_zero_unless_installed.sh"
source "${SH_DIR}/on_ci_publish_tagged_images.sh"
source "${SH_DIR}/remove_old_images.sh"
source "${SH_DIR}/remove_zombie_containers.sh"
source "${SH_DIR}/setup_dependent_images.sh"
source "${SH_DIR}/test_in_containers.sh"

source "${SH_DIR}/echo_versioner_env_vars.sh"
export $(echo_versioner_env_vars)

# - - - - - - - - - - - - - - - - - - - - - - - - - -
exit_zero_if_show_help "$@"
exit_non_zero_unless_installed docker
exit_non_zero_unless_installed docker-compose
exit_non_zero_unless_installed jq
remove_old_images
build_tagged_images "$@"
exit_zero_if_build_only "$@"
remove_zombie_containers
containers_down
setup_dependent_images
create_test_data_manifests_file
server_up_healthy_and_clean
client_up_healthy_and_clean "$@"
test_in_containers "$@"
containers_down
on_ci_publish_tagged_images
