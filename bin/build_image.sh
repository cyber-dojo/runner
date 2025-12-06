#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"
# shellcheck disable=SC2046
export $(echo_env_vars)

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: ${MY_NAME} {server|client}

    Options:
      server  - build the server image (local only)
      client  - build the client image (local and CI workflow)

EOF
}

check_args()
{
  case "${1:-}" in
    '-h' | '--help')
      show_help
      exit 0
      ;;
    'server')
      if [ -n "${CI:-}" ] ; then
        stderr "In CI workflow - use docker/build-push-action@v6 GitHub Action"
        exit_non_zero
      fi
      ;;
    'client')
      ;;
    '')
      show_help
      stderr "no argument - must be 'client' or 'server'"
      exit_non_zero
      ;;
    *)
      show_help
      stderr "argument is '${1:-}' - must be 'client' or 'server'"
      exit_non_zero
  esac
}

build_image()
{
  check_args "$@"
  local -r type="${1}"
  exit_non_zero_unless_installed docker
  containers_down

  if [ "${CI:-}" != 'true' ]; then
    # In CI workflow, don't remove image pulled in the 'Download docker image' CI workflow jobs.
    remove_old_images
    # Locally, client and server tests both need a server
    docker --log-level=ERROR compose build server
  fi

  echo
  echo "Building with --build-args"
  echo "  COMMIT_SHA=${COMMIT_SHA}"
  echo "To change this run:"
  echo "$ COMMIT_SHA=... make image_${type}"
  echo

  if [ "${type}" == 'client' ]; then
    docker --log-level=ERROR compose build client
  fi

  local -r image_name="${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}"
  local -r sha_in_image=$(docker run --rm --entrypoint="" "${image_name}" sh -c 'echo -n ${COMMIT_SHA}')
  if [ "${COMMIT_SHA}" != "${sha_in_image}" ]; then
    echo "ERROR: unexpected env-var inside image ${image_name}"
    echo "expected: 'COMMIT_SHA=${COMMIT_SHA}'"
    echo "  actual: 'COMMIT_SHA=${sha_in_image}'"
    exit_non_zero
  fi

  if [ "${type}" == 'server' ]; then
    # Create latest tag for image build cache
    docker tag "${image_name}" "${CYBER_DOJO_RUNNER_IMAGE}:latest"
    # Tag image-name for local development where runners name comes from echo-env-vars
    docker tag "${image_name}" "cyberdojo/runner:latest"
    echo "echo CYBER_DOJO_RUNNER_SHA=${CYBER_DOJO_RUNNER_SHA}"
    echo "echo CYBER_DOJO_RUNNER_TAG=${CYBER_DOJO_RUNNER_TAG}"
    echo "${image_name}"
  fi
}

build_image "$@"
