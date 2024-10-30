#!/usr/bin/env bash
set -Eeu

create_test_data_manifests_file()
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
    "${REPO}:${TAG}" \
    > /dev/null

  exit_non_zero_unless_healthy

  local -r URL="http://0.0.0.0:${CONTAINER_PORT}/manifests"
  local -r FILENAME="${ROOT_DIR}/test/data/languages_start_points.manifests.json"

  curl --silent --request GET "${URL}" | jq --sort-keys '.' > "${FILENAME}"

  docker rm --force "${CONTAINER_NAME}" > /dev/null
}
