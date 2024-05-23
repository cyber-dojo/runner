#!/usr/bin/env bash
set -Eeu

repo_root() { git rev-parse --show-toplevel; }
export SH_DIR="$(repo_root)/sh"
source "${SH_DIR}/exit_non_zero_unless_installed.sh"
source "${SH_DIR}/exit_zero_if_build_only.sh"
source "${SH_DIR}/exit_zero_if_show_help.sh"

exit_zero_if_show_help "$@"
exit_non_zero_unless_installed docker jq

"${SH_DIR}/build_tag.sh" "$@"
exit_zero_if_build_only "$@"
"${SH_DIR}/test.sh" "$@"
