#!/bin/bash -Eeu
readonly ROOT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd )"
readonly lsp_service_name=languages-start-points
readonly lsp_container_name=test-runner-languages-start-points
readonly lsp_port="${CYBER_DOJO_LANGUAGES_START_POINTS_PORT}"
source "${ROOT_DIR}/sh/wait_until_ready_and_clean.sh"

# - - - - - - - - - - - - - - - - - - - - - - - -
json_data()
{
  local -r display_name="${1}"
  cat <<- EOF
  { "name":"${display_name}" }
EOF
}

# - - - - - - - - - - - - - - - - - - - - - - - -
pull_dependent_images()
{
  echo
  echo Pulling images used in server-side tests
  # alpine:latest is used for tests showing bash must be in the image_name
  echo alpine:latest
  docker pull alpine:latest

  local -r display_names="$(
    docker run \
      --entrypoint='' \
      --rm \
      --volume ${ROOT_DIR}/test:/test/:ro \
        ${CYBER_DOJO_RUNNER_IMAGE} \
          ruby /test/dependent_display_names.rb)"

  echo "${display_names}" \
    | while read display_name
      do
        local json="$(json_data "${display_name}")"
        local manifest="$(curl \
          --data "${json}" \
          --silent \
          -X GET \
          "http://$(ip_address):${lsp_port}/manifest")"

        local image_name=$(echo "${manifest}" | jq --raw-output '.manifest.image_name')

        echo "${image_name}"
        docker pull "${image_name}"
      done

  echo
  echo Removing image pulled in client-side test
  echo busybox:glibc
  docker image rm busybox:glibc &> /dev/null || true
}

# - - - - - - - - - - - - - - - - - - - - - - - -
setup_dependent_images()
{
  echo
  docker-compose \
    --file "${ROOT_DIR}/docker-compose.yml" \
    up \
    -d \
    --force-recreate \
    "${lsp_service_name}"

  wait_until_ready_and_clean "${lsp_container_name}" "${lsp_port}"
  pull_dependent_images
}

# - - - - - - - - - - - - - - - - - - - - - - - -
if [ "${1:-}" != server ]; then
  setup_dependent_images
fi
