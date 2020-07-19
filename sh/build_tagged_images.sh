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
build_image()
{
  local -r service="${1}"
  echo
  docker-compose \
    --file "${ROOT_DIR}/docker-compose.yml" \
    build \
    --build-arg COMMIT_SHA=$(git_commit_sha) \
    "${service}"
}

#- - - - - - - - - - - - - - - - - - - - - - - -
build_images()
{
  if [ "${1:-}" == server ]; then
    build_image runner-server
  else
    build_image runner-server
    build_image runner-client
  fi
}

#- - - - - - - - - - - - - - - - - - - - - - - -
tag_image()
{
  local -r sha="$(image_sha)"
  local -r tag="${sha:0:7}"
  docker tag $(image_name):latest "$(image_name):${tag}"
  echo
  echo "CYBER_DOJO_RUNNER_SHA=${sha}"
  echo "CYBER_DOJO_RUNNER_TAG=${tag}"
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
  if [ "${expected}" != "${actual}" ]; then
    echo
    echo "${name} expected: ${expected}"
    echo "${name}   actual: ${actual}"
    echo ERROR assert_equal failed
    exit 42
  fi
}

#- - - - - - - - - - - - - - - - - - - - - - - -
remove_image
build_images "$@"
tag_image
assert_equal SHA  "$(git_commit_sha)"         "$(image_sha)"
assert_equal PORT "${CYBER_DOJO_RUNNER_PORT}" "$(image_port)"
