#!/usr/bin/env bash
set -Eeu

#- - - - - - - - - - - - - - - - - - - - - - - -
build_tagged_images()
{
  build_images "${@:-}"
  tag_images "${@:-}"
  check_embedded_env_var
  echo
  echo "echo CYBER_DOJO_RUNNER_TAG=$(image_tag)"
  echo "echo CYBER_DOJO_RUNNER_SHA=$(image_sha)"
  echo
}

#- - - - - - - - - - - - - - - - - - - - - - - -
build_images()
{
  if [ "${1}" == server ]; then
    local -r SERVICE=runner
  else
    local -r SERVICE=
  fi
  docker compose \
    build \
    --build-arg COMMIT_SHA=$(git_commit_sha) \
    ${SERVICE}
}

#- - - - - - - - - - - - - - - - - - - - - - - -
tag_images()
{
  docker tag ${CYBER_DOJO_RUNNER_IMAGE}:$(image_tag)        ${CYBER_DOJO_RUNNER_IMAGE}:latest
  if [ "${1}" != server ]; then
    docker tag ${CYBER_DOJO_RUNNER_CLIENT_IMAGE}:$(image_tag) ${CYBER_DOJO_RUNNER_CLIENT_IMAGE}:latest
  fi
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
  git rev-parse HEAD
}

#- - - - - - - - - - - - - - - - - - - - - - - -
image_name()
{
  echo "${CYBER_DOJO_RUNNER_IMAGE}"
}

# - - - - - - - - - - - - - - - - - - - - - -
image_sha()
{
  git_commit_sha
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
