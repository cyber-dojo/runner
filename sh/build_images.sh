#!/bin/bash -Eeu

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

#- - - - - - - - - - - - - - - - - - - - - - - -
remove_image()
{
  local -r sha="$(image_sha)"
  local -r tag="${sha:0:7}"
  docker image rm "$(image_name):${tag}" &> /dev/null | true
}

#- - - - - - - - - - - - - - - - - - - - - - - -
build_images()
{
  docker-compose \
    --file "${ROOT_DIR}/docker-compose.yml" \
    build \
    --build-arg COMMIT_SHA=$(git_commit_sha)
}

#- - - - - - - - - - - - - - - - - - - - - - - -
git_commit_sha()
{
  echo $(cd "${ROOT_DIR}" && git rev-parse HEAD)
}

#- - - - - - - - - - - - - - - - - - - - - - - -
image_name()
{
  echo "${CYBER_DOJO_RUNNER_IMAGE}"
}

#- - - - - - - - - - - - - - - - - - - - - - - -
image_sha()
{
  docker run --rm $(image_name):latest sh -c 'echo ${SHA}'
}

#- - - - - - - - - - - - - - - - - - - - - - - -
image_port()
{
  docker run --rm $(image_name):latest sh -c 'echo ${PORT}'
}

#- - - - - - - - - - - - - - - - - - - - - - - -
assert_equal()
{
  local -r name="${1}"
  local -r expected="${2}"
  local -r actual="${3}"
  echo
  echo "${name} expected: '${expected}'"
  echo "${name}   actual: '${actual}'"
  if [ "${expected}" != "${actual}" ]; then
    echo ERROR assert_equal failed
    exit 42
  fi
}

#- - - - - - - - - - - - - - - - - - - - - - - -
remove_image
build_images
assert_equal "$(git_commit_sha)"          "$(image_sha)"
assert_equal "${CYBER_DOJO_RUNNER_PORT}" "$(image_port)"
