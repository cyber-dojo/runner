#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"
source "${ROOT_DIR}/bin/echo_env_vars.sh"

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: bin/${MY_NAME}

    Pulls the runner image built for this commit from ECR, so a workflow can
    test against it without building it a second time.

    The main workflow builds and pushes this tag on every push, and ECR tags
    are immutable, so building it again under the same tag fails. Pulling what
    is already there is also what lets a workflow be re-run on one commit.

    Needs a docker login to ECR, which in a workflow comes from the
    aws-actions/amazon-ecr-login step.

    Options:
      -h    Show this help

    Example:
      bin/${MY_NAME}

EOF
}

check_args()
{
  case "${1:-}" in
    '-h' | '--help')
      show_help
      exit 0
      ;;
    '')
      ;;
    *)
      show_help
      stderr "argument is '${1}' - this script takes no arguments"
      exit_non_zero
      ;;
  esac
}

# Pulls this commit's runner image, naming what has to have happened first
# when it is not there to pull.
pull_runner_image()
{
  local -r tagged_name="${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}"
  echo "Pulling ${tagged_name}"
  if docker pull "${tagged_name}"; then
    return
  fi
  stderr "could not pull ${tagged_name}"
  stderr "The main workflow pushes this tag from its build-image job."
  stderr "Check that job has finished, and passed, for commit"
  stderr "${CYBER_DOJO_RUNNER_SHA}"
  exit_non_zero
}

if [ "${0}" = "${BASH_SOURCE[0]}" ]; then
  check_args "$@"
  exit_non_zero_unless_installed docker git
  # shellcheck disable=SC2046
  export $(echo_env_vars)
  pull_runner_image
fi
