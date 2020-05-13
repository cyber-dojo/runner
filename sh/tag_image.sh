#!/bin/bash -Ee

#- - - - - - - - - - - - - - - - - - - - - - - -
tag_image()
{
  local -r image="$(image_name)"
  local -r sha="$(image_sha)"
  local -r tag="${sha:0:7}"
  docker tag ${image}:latest "${image}:${tag}"
  echo "CYBER_DOJO_RUNNER_SHA=${sha}"
  echo "CYBER_DOJO_RUNNER_TAG=${tag}"
}

#- - - - - - - - - - - - - - - - - - - - - - - -
image_name()
{
  echo "${CYBER_DOJO_RUNNER_IMAGE}"
}

#- - - - - - - - - - - - - - - - - - - - - - - -
image_sha()
{
  docker run --rm "$(image_name):latest" sh -c 'echo ${SHA}'
}

#- - - - - - - - - - - - - - - - - - - - - - - -
tag_image
