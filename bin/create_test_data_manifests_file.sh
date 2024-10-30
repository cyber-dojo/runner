#!/usr/bin/env bash
set -Eeu

create_test_data_manifests_file()
{
  # run an LSP container
  #local -r REPO="${CYBER_DOJO_LANGUAGES_START_POINTS_IMAGE}"
  #local -r TAG="${CYBER_DOJO_LANGUAGES_START_POINTS_TAG}"

  docker compose --progress=plain up --no-build --wait --wait-timeout=10 languages-start-points

  local -r PORT="${CYBER_DOJO_LANGUAGES_START_POINTS_PORT}"
  local -r URL="http://0.0.0.0:${PORT}/manifests"
  local -r FILENAME="${ROOT_DIR}/test/data/languages_start_points.manifests.json"

  curl --silent --request GET "${URL}" | jq --sort-keys '.' > "${FILENAME}"

  docker compose down languages-start-points
}
