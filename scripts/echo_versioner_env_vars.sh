#!/bin/bash -Eeu

# - - - - - - - - - - - - - - - - - - - - - - - -
echo_versioner_env_vars()
{
  docker run --rm cyberdojo/versioner:latest
  #
  echo CYBER_DOJO_RUNNER_SHA="$(image_sha)"
  echo CYBER_DOJO_RUNNER_TAG="$(image_tag)"
  #
  echo CYBER_DOJO_RUNNER_CLIENT_IMAGE=cyberdojo/runner-client
  echo CYBER_DOJO_RUNNER_CLIENT_PORT=9999
  #
  echo CYBER_DOJO_RUNNER_CLIENT_USER=nobody
  echo CYBER_DOJO_RUNNER_SERVER_USER=root
  #
  echo CYBER_DOJO_RUNNER_CLIENT_CONTAINER_NAME=test_runner_client
  echo CYBER_DOJO_RUNNER_SERVER_CONTAINER_NAME=test_runner_server
}

# - - - - - - - - - - - - - - - - - - - - - - - -
image_sha()
{
  echo "$(cd "${ROOT_DIR}" && git rev-parse HEAD)"
}

# - - - - - - - - - - - - - - - - - - - - - - - -
image_tag()
{
  local -r sha="$(image_sha)"
  echo "${sha:0:7}"
}
