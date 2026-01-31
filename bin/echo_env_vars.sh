#!/usr/bin/env bash
set -Eeu

echo_env_vars()
{
  # Setup port env-vars in .env file using versioner
  {
    echo "# This file is generated in bin/lib.sh echo_env_vars()"
    echo "CYBER_DOJO_RUNNER_CLIENT_PORT=9999"
    echo "CYBER_DOJO_PROMETHEUS=true"
    docker run --rm cyberdojo/versioner 2> /dev/null | grep PORT
  } > "${ROOT_DIR}/.env"

  # Get identities of dependent services from versioner
  docker run --rm cyberdojo/versioner 2> /dev/null
  export $(docker run --rm cyberdojo/versioner 2> /dev/null)
  echo "CYBER_DOJO_LANGUAGES_START_POINTS=${CYBER_DOJO_LANGUAGES_START_POINTS_IMAGE}:${CYBER_DOJO_LANGUAGES_START_POINTS_TAG}@sha256:${CYBER_DOJO_LANGUAGES_START_POINTS_DIGEST}"

  local -r sha="$(cd "${ROOT_DIR}" && git rev-parse HEAD)"

  # Set env-vars for this repos runner service
  if [[ ! -v COMMIT_SHA ]] ; then
    echo COMMIT_SHA="${sha}"  # --build-arg
  fi

  echo CYBER_DOJO_RUNNER_SHA="${sha}"
  echo CYBER_DOJO_RUNNER_TAG="${sha:0:7}"

  echo CYBER_DOJO_RUNNER_CLIENT_IMAGE=cyberdojo/runner-client
  echo CYBER_DOJO_RUNNER_CLIENT_PORT=9999

  echo CYBER_DOJO_RUNNER_CLIENT_USER=nobody
  echo CYBER_DOJO_RUNNER_SERVER_USER=root

  echo CYBER_DOJO_RUNNER_CLIENT_CONTAINER_NAME=test_runner_client
  echo CYBER_DOJO_RUNNER_SERVER_CONTAINER_NAME=test_runner_server

  echo COVERAGE_CODE_TAB_NAME=code
  echo COVERAGE_TEST_TAB_NAME=test

  local -r AWS_ACCOUNT_ID=244531986313
  local -r AWS_REGION=eu-central-1
  echo CYBER_DOJO_RUNNER_IMAGE="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/runner"
}
