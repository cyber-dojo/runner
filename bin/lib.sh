#!/usr/bin/env bash
set -Eeu

exit_non_zero_unless_installed()
{
  for dependent in "$@"
  do
    if ! installed "${dependent}" ; then
      stderr "${dependent} is not installed!"
      exit 42
    fi
  done
}

installed()
{
  if hash "${1}" &> /dev/null; then
    true
  else
    false
  fi
}

stderr()
{
  local -r message="${1}"
  >&2 echo "ERROR: ${message}"
}

exit_non_zero_unless_file_exists()
{
  local -r filename="${1}"
  if [ ! -f "${filename}" ]; then
    echo "ERROR: ${filename} does not exist"
    exit 42
  fi
}

abs_filename()
{
  echo "$(cd "$(dirname "${1}")" && pwd)/$(basename "${1}")"
}

containers_down()
{
  docker compose down --remove-orphans --volumes
}

echo_versioner_env_vars()
{
  local -r sha="$(cd "${ROOT_DIR}" && git rev-parse HEAD)"
  echo COMMIT_SHA="${sha}"

  docker run --rm cyberdojo/versioner

  echo CYBER_DOJO_RUNNER_SHA="${sha}"
  echo CYBER_DOJO_RUNNER_TAG="${sha:0:7}"
  #
  echo CYBER_DOJO_RUNNER_CLIENT_IMAGE=cyberdojo/runner-client
  echo CYBER_DOJO_RUNNER_CLIENT_PORT=9999
  #
  echo CYBER_DOJO_RUNNER_CLIENT_USER=nobody
  echo CYBER_DOJO_RUNNER_SERVER_USER=root
  #
  echo CYBER_DOJO_RUNNER_CLIENT_CONTAINER_NAME=test_runner_client
  echo CYBER_DOJO_RUNNER_SERVER_CONTAINER_NAME=test_runner_server
  #
  local -r AWS_ACCOUNT_ID=244531986313
  local -r AWS_REGION=eu-central-1
  echo CYBER_DOJO_RUNNER_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/runner"
}

remove_old_images()
{
  echo Removing old images
  local -r dil=$(docker image ls --format "{{.Repository}}:{{.Tag}}" | grep runner)
  remove_all_but_latest "${dil}" "${CYBER_DOJO_RUNNER_CLIENT_IMAGE}"
  remove_all_but_latest "${dil}" "${CYBER_DOJO_RUNNER_IMAGE}"
  remove_all_but_latest "${dil}" cyberdojo/runner
}

remove_all_but_latest()
{
  # Keep latest in the cache
  local -r docker_image_ls="${1}"
  local -r name="${2}"
  for image_name in $(echo "${docker_image_ls}" | grep "${name}:")
  do
    if [ "${image_name}" != "${name}:latest" ]; then
      docker image rm "${image_name}"
    fi
  done
  docker system prune --force
}
