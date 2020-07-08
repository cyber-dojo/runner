#!/bin/bash -Eeu

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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
  docker run --rm $(image_name):latest sh -c 'env | grep SHA='
}

#- - - - - - - - - - - - - - - - - - - - - - - -
image_port()
{
  docker run --rm $(image_name):latest sh -c 'env | grep PORT='
}

#- - - - - - - - - - - - - - - - - - - - - - - -
assert_equal()
{
  local -r expected="${1}"
  local -r actual="${2}"
  echo
  echo "expected: '${expected}'"
  echo "  actual: '${actual}'"
  if [ "${expected}" != "${actual}" ]; then
    echo ERROR assert_equal failed
    exit 42
  fi
}

#- - - - - - - - - - - - - - - - - - - - - - - -
build_images
assert_equal "SHA=$(git_commit_sha)"          "$(image_sha)"
assert_equal "PORT=${CYBER_DOJO_RUNNER_PORT}" "$(image_port)"
