#!/bin/bash -Eeu

readonly ROOT_DIR="$( cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd )"
source "${ROOT_DIR}/sh/wait_until_ready_and_clean.sh"

# - - - - - - - - - - - - - - - - - - - - - - - -
setup_dependent_images()
{
  echo
  echo Pulling images used in server-side tests

  local -r image_names=($(docker run \
    --entrypoint='' \
    --network runner_default \
    --rm \
    --volume ${ROOT_DIR}/test:/test/:ro \
    ${CYBER_DOJO_RUNNER_IMAGE} ruby /test/dependent_image_names.rb))

  for image_name in "${image_names[@]}"
  do
    echo "${image_name}"
    docker pull "${image_name}"
  done

  echo Removing image pulled in client-side test
  docker image rm busybox:glibc &> /dev/null || true
}

# - - - - - - - - - - - - - - - - - - - - - - - -
readonly lsp_container_name=test-runner-languages-start-points
readonly lsp_port="${CYBER_DOJO_LANGUAGES_START_POINTS_PORT}"

echo
docker-compose \
  --file "${ROOT_DIR}/docker-compose.yml" \
  up \
  -d \
  --force-recreate \
  languages-start-points

wait_until_ready_and_clean "${lsp_container_name}" "${lsp_port}"
setup_dependent_images
