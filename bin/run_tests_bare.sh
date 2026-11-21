#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"

# The server tests, run without the deployed image: in the bare image, the
# Dockerfile's base stage (Ruby, its gems and the OS packages, with no source
# code), as docker-compose.bare.yml lays it over docker-compose.yml. Then
# bin/run_tests.sh and bin/check_coverage.sh run as they do for the deployed
# image. The bare image's packages are saved to
# reports/server/bare_image_packages.txt (see bin/image_packages.sh).

readonly LOCAL_BARE_IMAGE=runner-bare-image:local

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: ${MY_NAME} [ID...]

    Runs the server tests, then checks their coverage and other metrics, in
    the bare image: the one named by CYBER_DOJO_RUNNER_BARE_IMAGE, or else
    one built here with docker build --target base (${LOCAL_BARE_IMAGE}).
    Writes reports/server, as bin/run_tests.sh server does, and
    reports/server/bare_image_packages.txt.

    Options:
       -h     Show this help
       ID...  Only run tests matching these identifiers (no metrics checks)

    Example:
       ${MY_NAME}
       CYBER_DOJO_RUNNER_BARE_IMAGE=runner-bare-image:ab12cd3 ${MY_NAME} a2D

EOF
}

# The bare image: the one given, or one built from the Dockerfile's base stage.
bare_image()
{
  if [ -n "${CYBER_DOJO_RUNNER_BARE_IMAGE:-}" ]; then
    echo "${CYBER_DOJO_RUNNER_BARE_IMAGE}"
  else
    docker build --target base --tag "${LOCAL_BARE_IMAGE}" "${ROOT_DIR}" >&2
    echo "${LOCAL_BARE_IMAGE}"
  fi
}

# The packages of the server container the tests ran in, which is left up.
save_bare_image_packages()
{
  local -r reports_dir="${ROOT_DIR}/reports/server"
  # Short flag: macOS's mkdir has no --parents.
  mkdir -p "${reports_dir}"
  "${ROOT_DIR}/bin/image_packages.sh" container "$(service_container server)" \
      > "${reports_dir}/bare_image_packages.txt"
  echo "server test bare image packages are at:"
  echo "${reports_dir}/bare_image_packages.txt"
  echo
}

main()
{
  case "${1:-}" in
    '-h' | '--help')
      show_help
      exit 0
      ;;
  esac
  exit_non_zero_unless_installed docker
  CYBER_DOJO_RUNNER_BARE_IMAGE="$(bare_image)"
  export CYBER_DOJO_RUNNER_BARE_IMAGE
  export COMPOSE_FILE="${ROOT_DIR}/docker-compose.yml:${ROOT_DIR}/docker-compose.bare.yml"
  # The scripts that run plain ruby (the dependent images' display names,
  # the metrics check) run it in the bare image too, as no deployed image
  # has been built.
  export CYBER_DOJO_RUNNER_RUBY_IMAGE="${CYBER_DOJO_RUNNER_BARE_IMAGE}"

  # No earlier run's reports may stand in for this run's.
  rm -rf "${ROOT_DIR}/reports/server"
  local status=0
  "${ROOT_DIR}/bin/run_tests.sh" server "$@" || status=1
  save_bare_image_packages
  if [ "$#" == 0 ]; then
    "${ROOT_DIR}/bin/check_coverage.sh" server || status=1
  fi
  return "${status}"
}

main "$@"
