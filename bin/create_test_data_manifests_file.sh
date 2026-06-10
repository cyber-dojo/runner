#!/usr/bin/env bash
set -Eeu

create_test_data_manifests_file()
{
  # Regenerate the test fixture holding every language start-point's manifest.
  # The languages-start-points service no longer publishes a host port (so
  # demos/tests in this and sibling repos can run at once without colliding),
  # so reach it the same way the rest of the suite does: docker exec into the
  # container, resolved by compose project+service via service_container(),
  # and curl its in-container localhost.
  #
  # Write to a temp file first and only replace the committed fixture once we
  # have valid, non-empty JSON. A failed fetch must not silently truncate the
  # good fixture to an empty file (which makes every manifest-reading test die
  # with a JSON::ParserError).
  local -r PORT="${CYBER_DOJO_LANGUAGES_START_POINTS_PORT}"
  local -r FILENAME="${ROOT_DIR}/test/data/languages_start_points.manifests.json"
  local -r TMP_FILENAME="${FILENAME}.tmp"

  docker compose --progress=plain up --no-build --wait --wait-timeout=10 languages-start-points
  local -r CONTAINER="$(service_container languages-start-points)"
  if [ -z "${CONTAINER}" ]; then
    stderr "could not resolve the languages-start-points container"
    exit_non_zero
  fi

  # set +e so a failed fetch (or jq on empty input) does not abort via set -e
  # before the non-empty guard below runs and prints a clear message.
  set +e
  docker exec "${CONTAINER}" \
    curl --silent --fail --request GET "http://localhost:${PORT}/manifests" \
      | jq --sort-keys '.' > "${TMP_FILENAME}"
  set -e

  if [ ! -s "${TMP_FILENAME}" ]; then
    rm -f "${TMP_FILENAME}"
    stderr "fetched manifests were empty - leaving ${FILENAME} unchanged"
    exit_non_zero
  fi
  mv "${TMP_FILENAME}" "${FILENAME}"

  docker compose down languages-start-points
}
