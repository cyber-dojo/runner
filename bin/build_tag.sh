#!/usr/bin/env bash
set -Eeu

repo_root() { git rev-parse --show-toplevel; }
export BIN_DIR="$(repo_root)/bin"

source "${BIN_DIR}/build_tagged_images.sh"
source "${BIN_DIR}/remove_old_images.sh"
source "${BIN_DIR}/echo_versioner_env_vars.sh"
export $(echo_versioner_env_vars)

remove_old_images
build_tagged_images "$@"
