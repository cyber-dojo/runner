#!/bin/bash -Eeu

source "${SH_DIR}/ip_address.sh"
readonly IP_ADDRESS=$(ip_address)

#- - - - - - - - - - - - - - - - - - - - - - - -
create_test_data_manifest_files()
{
  # run an LSP container
  local -r REPO="${CYBER_DOJO_LANGUAGES_START_POINTS_IMAGE}"
  local -r TAG="${CYBER_DOJO_LANGUAGES_START_POINTS_TAG}"

  export SERVICE_NAME=languages_start_points
  export CONTAINER_PORT="${CYBER_DOJO_LANGUAGES_START_POINTS_PORT}"
  export CONTAINER_NAME=runner_test_languages_start_points

  docker run \
    --name "${CONTAINER_NAME}" \
    --detach \
    --publish "${CONTAINER_PORT}:${CONTAINER_PORT}" \
    "${REPO}:${TAG}"

  exit_non_zero_unless_healthy

  curl --silent --request GET http://${IP_ADDRESS}:${CONTAINER_PORT}/manifests | jq '.' \
    > "${ROOT_DIR}/test/data/languages_start_points.manifests.json"

  docker rm --force "${CONTAINER_NAME}" > /dev/null
}
