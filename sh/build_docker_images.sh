#!/bin/bash -Eeu

readonly ROOT_DIR="$( cd "$( dirname "${0}" )/.." && pwd )"

#- - - - - - - - - - - - - - - - - - - - - - - -
build_images()
{
  docker-compose \
    --file "${ROOT_DIR}/docker-compose.yml" \
    build \
    --build-arg COMMIT_SHA=$(git_commit_sha) \
    --build-arg CYBER_DOJO_RUNNER_PORT=${CYBER_DOJO_RUNNER_PORT}
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
assert_equal()
{
  local -r expected="${1}"
  local -r actual="${2}"
  if [ "${expected}" != "${actual}" ]; then
    echo ERROR
    echo "expected: '${expected}'"
    echo "  actual: '${actual}'"
    exit 42
  fi
}

#- - - - - - - - - - - - - - - - - - - - - - - -
build_images
assert_equal "SHA=$(git_commit_sha)" "$(image_sha)"
