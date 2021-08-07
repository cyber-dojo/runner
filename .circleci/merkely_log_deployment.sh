#!/bin/bash -Eeu

MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MERKELY_CHANGE=merkely/change:latest
MERKELY_OWNER=cyber-dojo
MERKELY_PIPELINE=runner

readonly ENVIRONMENT="${1}"
readonly HOSTNAME="${2}"

# - - - - - - - - - - - - - - - - - - -
merkely_fingerprint()
{
  echo "docker://${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}"
}

# - - - - - - - - - - - - - - - - - - -
merkely_log_deployment()
{
  VERSIONER_URL=https://raw.githubusercontent.com/cyber-dojo/versioner/master
  export $(curl "${VERSIONER_URL}/app/.env")
  export CYBER_DOJO_RUNNER_TAG="${CIRCLE_SHA1:0:7}"
  docker pull ${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}

	docker run \
      --env MERKELY_COMMAND=log_deployment \
      --env MERKELY_OWNER=${MERKELY_OWNER} \
      --env MERKELY_PIPELINE=${MERKELY_PIPELINE} \
      --env MERKELY_FINGERPRINT=$(merkely_fingerprint) \
      --env MERKELY_DESCRIPTION="Deployed to ${environment} in circleci pipeline" \
      --env MERKELY_ENVIRONMENT="${ENVIRONMENT}" \
      --env MERKELY_CI_BUILD_URL=${CIRCLE_BUILD_URL} \
      --env MERKELY_API_TOKEN=${MERKELY_API_TOKEN} \
      --env MERKELY_HOST="${HOSTNAME}" \
      --rm \
      --volume /var/run/docker.sock:/var/run/docker.sock \
    	    ${MERKELY_CHANGE}
}

merkely_log_deployment
