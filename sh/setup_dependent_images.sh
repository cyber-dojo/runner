#!/usr/bin/env bash
set -Eeu

repo_root() { git rev-parse --show-toplevel; }

# - - - - - - - - - - - - - - - - - - - - - - - -
setup_dependent_images()
{
  if [ "${1:-}" != server ]; then
    pull_dependent_images
  fi
  remove_pulled_image
}

# - - - - - - - - - - - - - - - - - - - - - - - -
pull_dependent_images()
{
  echo
  echo Pulling images used in server-side tests

  local -r IMAGE_NAMES=$(docker image ls --format '{{.Repository}}:{{.Tag}}' | sort | uniq)

  if ! echo "${IMAGE_NAMES}" | grep alpine:latest ; then
    # alpine:latest is used for tests showing bash must be in the image_name
    docker pull alpine:latest
  fi

  local -r DISPLAY_NAMES="$(
    docker run \
      --entrypoint='' \
      --rm \
      --volume $(repo_root)/test:/test/:ro \
        ${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG} \
          ruby /test/dependent_display_names.rb)"

  local -r JSON_DATA=$(docker run --rm \
    ${CYBER_DOJO_LANGUAGES_START_POINTS_IMAGE}:${CYBER_DOJO_LANGUAGES_START_POINTS_TAG} \
    bash -c 'ruby /app/repos/inspect.rb')

  echo "${DISPLAY_NAMES}" \
    | while read display_name
      do
        local image_name=$(echo "${JSON_DATA}" | jq --raw-output ".[\"${display_name}\"].image_name")
        if ! echo "${IMAGE_NAMES}" | grep "${image_name}" ; then
          docker pull "${image_name}"
        fi
      done
}

# - - - - - - - - - - - - - - - - - - - - - - - -
remove_pulled_image()
{
  echo
  echo Removing image pulled in client-side test
  echo busybox:glibc
  docker image rm busybox:glibc > /dev/null 2>&1 || true
}
