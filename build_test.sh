#!/usr/bin/env bash
set -Eeu

repo_root() { git rev-parse --show-toplevel; }
export SH_DIR="$(repo_root)/sh"
source "${SH_DIR}/exit_non_zero_unless_installed.sh"
source "${SH_DIR}/exit_zero_if_build_only.sh"
source "${SH_DIR}/exit_zero_if_show_help.sh"

exit_zero_if_show_help "$@"
exit_non_zero_unless_installed docker
exit_non_zero_unless_installed docker-compose
exit_non_zero_unless_installed jq

"${SH_DIR}/build_tag.sh" "$@"
exit_zero_if_build_only "$@"
# TODO: handle $@ options for [server|client] [ID...]
"${SH_DIR}/test.sh" "$@"
