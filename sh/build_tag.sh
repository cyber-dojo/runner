#!/usr/bin/env bash
set -Eeu

repo_root() { git rev-parse --show-toplevel; }
export SH_DIR="$(repo_root)/sh"

source "${SH_DIR}/build_tagged_images.sh"
source "${SH_DIR}/remove_old_images.sh"
source "${SH_DIR}/echo_versioner_env_vars.sh"
export $(echo_versioner_env_vars)

remove_old_images
build_tagged_images "$@"
