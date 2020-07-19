#!/bin/bash -Eeu
readonly SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/sh" && pwd )"
source ${SH_DIR}/versioner_env_vars.sh
export $(versioner_env_vars)

# - - - - - - - - - - - - - - - - - - - - - - - - - -
exit_zero_if_show_help()
{
  if show_help_arg "${1:-}"; then
    local -r my_name=`basename "${BASH_SOURCE[0]}"`
    cat <<- EOF

    Use: ${my_name} [client|server] [ID...]

    Options:
       client  - only run tests from inside the client
       server  - only run tests from inside the server
       ID...   - only run tests matching these identifiers

    To see the test ID and filename as each test runs:
       SHOW_TEST_IDS=true ${my_name} [client|server] [ID...]

EOF
    exit 0
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
show_help_arg()
{
  [ "${1:-}" == '--help' ] || [ "${1:-}" == '-h' ]
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
exit_zero_if_build_only()
{
  if build_only_arg "${1:-}" ; then
    exit 0
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
build_only_arg()
{
  [ "${1:-}" == '--build-only' ] || [ "${1:-}" == '-bo' ]
}

# - - - - - - - - - - - - - - - - - - - - - - - - - -
exit_zero_if_show_help "$@"
${SH_DIR}/build_tagged_images.sh "$@"
exit_zero_if_build_only "$@"
${SH_DIR}/tear_down.sh
${SH_DIR}/setup_dependent_images.sh "$@"
${SH_DIR}/containers_up.sh "$@"
${SH_DIR}/test_in_containers.sh "$@"
${SH_DIR}/containers_down.sh
${SH_DIR}/on_ci_publish_tagged_images.sh
