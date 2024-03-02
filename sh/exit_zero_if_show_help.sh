#!/usr/bin/env bash
set -Eeu

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
