#!/usr/bin/env bash
set -Eeu

# - - - - - - - - - - - - - - - - - - - - - - - -
on_ci_publish_tagged_images()
{
  if ! on_ci; then
    echo
    echo 'not on CI so not publishing tagged images'
    return
  fi
  #if git log -1 --pretty=%B | grep --quiet '[test-only]'; then
  #  echo 'commit message contains [test-only] so stopping here'
  #  return
  #fi
  echo
  echo 'on CI so publishing tagged images'
  local -r image="$(image_name)"
  local -r sha="$(image_sha)"
  local -r tag=${sha:0:7}
  docker push ${image}:latest
  docker push ${image}:${tag}
}

# - - - - - - - - - - - - - - - - - - - - - - - -
on_ci()
{
  [ -n "${CIRCLECI:-}" ]
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
