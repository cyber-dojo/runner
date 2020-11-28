#!/bin/bash -Eeu

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
        ${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG} \
          ruby /test/dependent_display_names.rb)"

  local -r json_data=$(docker run --rm \
    ${CYBER_DOJO_LANGUAGES_START_POINTS_IMAGE}:${CYBER_DOJO_LANGUAGES_START_POINTS_TAG} \
    bash -c 'ruby /app/repos/inspect.rb')

  echo "${display_names}" \
    | while read display_name
      do
        local image_name=$(echo "${json_data}" | jq --raw-output ".[\"${display_name}\"].image_name")
        echo "${image_name}"
        docker pull "${image_name}"
      done

  echo
  echo Removing image pulled in client-side test
  echo busybox:glibc
  docker image rm busybox:glibc &> /dev/null || true
}
