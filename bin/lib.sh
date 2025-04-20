#!/usr/bin/env bash
set -Eeu

echo_base_image()
{
  # This is set to the env-var BASE_IMAGE which is set as a docker compose build --build-arg
  # and used the Dockerfile's 'FROM ${BASE_IMAGE}' statement
  # This BASE_IMAGE abstraction is to facilitate the base_image_update.yml workflow.
  #echo_base_image_via_curl
  echo_base_image_via_code
}

echo_base_image_via_curl()
{
  local -r json="$(curl --fail --silent --request GET https://beta.cyber-dojo.org/runner/base_image)"
  echo "${json}" | jq -r '.base_image'
}

echo_base_image_via_code()
{
  # An alternative echo_base_image for local development and for initial base-image upgrade.
  local -r tag=4276739
  local -r digest=5cdac61a3333e302982b51e8b2c431650d1e6967a3aa3ea4d94c74cbc790c99a
  echo "cyberdojo/docker-base:${tag}@sha256:${digest}"
}

echo_env_vars()
{
  # Setup port env-vars in .env file using versioner
  local -r env_filename="${ROOT_DIR}/.env"
  docker run --rm cyberdojo/versioner 2> /dev/null | grep PORT > "${env_filename}"
  echo "CYBER_DOJO_PROMETHEUS=true" >> "${env_filename}"
  echo "CYBER_DOJO_RUNNER_CLIENT_PORT=9999" >> "${env_filename}"

  # Get identities of dependent services from versioner
  docker run --rm cyberdojo/versioner 2> /dev/null
  export $(docker run --rm cyberdojo/versioner 2> /dev/null)
  echo "CYBER_DOJO_LANGUAGES_START_POINTS=${CYBER_DOJO_LANGUAGES_START_POINTS_IMAGE}:${CYBER_DOJO_LANGUAGES_START_POINTS_TAG}@sha256:${CYBER_DOJO_LANGUAGES_START_POINTS_DIGEST}"

  # Set env-vars for this repos runner service
  if [[ ! -v BASE_IMAGE ]] ; then
    echo BASE_IMAGE="$(echo_base_image)"  # --build-arg
  fi
  if [[ ! -v COMMIT_SHA ]] ; then
    local -r sha="$(cd "${ROOT_DIR}" && git rev-parse HEAD)"
    echo COMMIT_SHA="${sha}"  # --build-arg
  fi

  echo CYBER_DOJO_RUNNER_SHA="${sha}"
  echo CYBER_DOJO_RUNNER_TAG="${sha:0:7}"

  echo CYBER_DOJO_RUNNER_CLIENT_IMAGE=cyberdojo/runner-client
  echo CYBER_DOJO_RUNNER_CLIENT_PORT=9999

  echo CYBER_DOJO_RUNNER_CLIENT_USER=nobody
  echo CYBER_DOJO_RUNNER_SERVER_USER=root

  echo CYBER_DOJO_RUNNER_CLIENT_CONTAINER_NAME=test_runner_client
  echo CYBER_DOJO_RUNNER_SERVER_CONTAINER_NAME=test_runner_server

  local -r AWS_ACCOUNT_ID=244531986313
  local -r AWS_REGION=eu-central-1
  echo CYBER_DOJO_RUNNER_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/runner"
}

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
    stderr "${filename} does not exist"
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

echo_warnings()
{
  local -r SERVICE_NAME="${1}" # {client|server}
  local -r DOCKER_LOG=$(docker logs "${CONTAINER_NAME}" 2>&1)
  # Handle known warnings (eg waiting on Gem upgrade)
  # local -r SHADOW_WARNING="server.rb:(.*): warning: shadowing outer local variable - filename"
  # DOCKER_LOG=$(strip_known_warning "${DOCKER_LOG}" "${SHADOW_WARNING}")

  if echo "${DOCKER_LOG}" | grep --quiet "warning" ; then
    echo "Warnings in ${SERVICE_NAME} container"
    echo "${DOCKER_LOG}"
  fi
}

strip_known_warning()
{
  local -r DOCKER_LOG="${1}"
  local -r KNOWN_WARNING="${2}"
  local -r STRIPPED=$(echo -n "${DOCKER_LOG}" | grep --invert-match -E "${KNOWN_WARNING}")
  if [ "${DOCKER_LOG}" != "${STRIPPED}" ]; then
    echo "Known service start-up warning found: ${KNOWN_WARNING}"
  else
    echo "Known service start-up warning NOT found: ${KNOWN_WARNING}"
    exit 42
  fi
  echo "${STRIPPED}"
}
