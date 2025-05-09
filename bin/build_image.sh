#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "${ROOT_DIR}/bin/lib.sh"

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
        exit 42
      fi
      ;;
    'client')
      ;;
    '')
      show_help
      stderr "no argument - must be 'client' or 'server'"
      exit 42
      ;;
    *)
      show_help
      stderr "argument is '${1:-}' - must be 'client' or 'server'"
      exit 42
  esac
}

build_image()
{
  check_args "$@"
  local -r type="${1}"
  exit_non_zero_unless_installed docker
  # shellcheck disable=SC2046
  export $(echo_env_vars)
  containers_down

  # Commenting out the removal of old images because it currently deleted the image
  # pulled just after the secure-docker-build workflow runs.
  # remove_old_images

  echo
  echo "Building with --build-args"
  echo "  COMMIT_SHA=${COMMIT_SHA}"
  echo "To change this run:"
  echo "$ COMMIT_SHA=... make image_${type}"
  echo

  docker --log-level=ERROR compose build server
  if [ "${type}" == 'client' ]; then
    docker --log-level=ERROR compose build client
  fi

  local -r image_name="${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}"
  local -r sha_in_image=$(docker run --rm --entrypoint="" "${image_name}" sh -c 'echo -n ${SHA}')
  if [ "${COMMIT_SHA}" != "${sha_in_image}" ]; then
    echo "ERROR: unexpected env-var inside image ${image_name}"
    echo "expected: 'SHA=${COMMIT_SHA}'"
    echo "  actual: 'SHA=${sha_in_image}'"
    exit 42
  fi

  if [ "${type}" == 'server' ]; then
    # Create latest tag for image build cache
    docker tag "${image_name}" "${CYBER_DOJO_RUNNER_IMAGE}:latest"
    # Tag image-name for local development where runners name comes from echo-env-vars
    docker tag "${image_name}" "cyberdojo/runner:latest"
    echo "CYBER_DOJO_RUNNER_SHA=${CYBER_DOJO_RUNNER_SHA}"
    echo "CYBER_DOJO_RUNNER_TAG=${CYBER_DOJO_RUNNER_TAG}"
    echo "${image_name}"
  fi
}

build_image "$@"
