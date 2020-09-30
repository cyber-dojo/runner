#!/bin/bash -Eeu

#- - - - - - - - - - - - - - - - - - - - - - - -
build_tagged_images()
{
  local -r dil=$(docker image ls --format "{{.Repository}}:{{.Tag}}")
  remove_all_but_latest "${dil}" "${CYBER_DOJO_RUNNER_IMAGE}"
  remove_all_but_latest "${dil}" "${CYBER_DOJO_RUNNER_CLIENT_IMAGE}"

  build_images
  tag_images
  check_embedded_env_var

  echo
  echo "CYBER_DOJO_RUNNER_TAG=$(image_tag)"
  echo "CYBER_DOJO_RUNNER_SHA=$(image_sha)"
  echo
}

# - - - - - - - - - - - - - - - - - - - - - -
remove_all_but_latest()
{
  local -r docker_image_ls="${1}"
  local -r name="${2}"
  for image_name in `echo "${docker_image_ls}" | grep "${name}:"`
  do
    if [ "${image_name}" != "${name}:latest" ]; then
      if [ "${image_name}" != "${name}:<none>" ]; then
        docker image rm "${image_name}"
      fi
    fi
  done
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
tag_images()
{
  docker tag ${CYBER_DOJO_RUNNER_IMAGE}:$(image_tag)        ${CYBER_DOJO_RUNNER_IMAGE}:latest
  docker tag ${CYBER_DOJO_RUNNER_CLIENT_IMAGE}:$(image_tag) ${CYBER_DOJO_RUNNER_CLIENT_IMAGE}:latest
}

# - - - - - - - - - - - - - - - - - - - - - -
check_embedded_env_var()
{
  if [ "$(git_commit_sha)" != "$(sha_in_image)" ]; then
    echo "ERROR: unexpected env-var inside image $(image_name):$(image_tag)"
    echo "expected: 'SHA=$(git_commit_sha)'"
    echo "  actual: 'SHA=$(sha_in_image)'"
    exit 42
  fi
}

# - - - - - - - - - - - - - - - - - - - - - -
# - - - - - - - - - - - - - - - - - - - - - -
image_exists()
{
  local -r name="${1}"
  local -r tag="${2}"
  local -r latest=$(docker image ls --format "{{.Repository}}:{{.Tag}}" | grep "${name}:${tag}")
  [ "${latest}" != '' ]
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

# - - - - - - - - - - - - - - - - - - - - - -
image_sha()
{
  echo "$(git_commit_sha)"
}

# - - - - - - - - - - - - - - - - - - - - - -
image_tag()
{
  local -r sha="${image_sha}"
  echo "${sha:0:7}"
}

#- - - - - - - - - - - - - - - - - - - - - - - -
sha_in_image()
{
  docker run --rm $(image_name):$(image_tag) sh -c 'echo -n ${SHA}'
}
