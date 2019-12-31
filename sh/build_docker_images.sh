#!/bin/bash -Ee

readonly ROOT_DIR="$( cd "$( dirname "${0}" )" && cd .. && pwd )"
readonly IMAGE=cyberdojo/runner
export COMMIT_SHA=$(cd "${ROOT_DIR}" && git rev-parse HEAD)

#- - - - - - - - - - - - - - - - - - - - - - - -
build_service_images()
{
  echo
  docker-compose \
    --file "${ROOT_DIR}/docker-compose.yml" \
    build
}

#- - - - - - - - - - - - - - - - - - - - - - - -
images_sha_env_var()
{
  docker run --rm ${IMAGE}:latest sh -c 'env | grep SHA'
}

#- - - - - - - - - - - - - - - - - - - - - - - -
build_service_images
if [ "SHA=${COMMIT_SHA}" != $(images_sha_env_var) ]; then
  echo "unexpected env-var inside image ${IMAGE}:latest"
  echo "expected: 'SHA=${COMMIT_SHA}'"
  echo "  actual: '$(images_sha_env_var)'"
  exit 42
fi
