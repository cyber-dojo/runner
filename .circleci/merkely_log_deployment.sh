#!/bin/bash -Eeu


# - - - - - - - - - - - - - - - - - - -
merkely_log_deployment()
{
  local -r MERKELY_ENVIRONMENT="${1}"
  local -r MERKELY_HOST="${2}"
  local -r MERKELY_OWNER=cyber-dojo
  local -r MERKELY_PIPELINE=runner

  # Set CYBER_DOJO_RUNNER_IMAGE, CYBER_DOJO_RUNNER_TAG
  local -r VERSIONER_URL=https://raw.githubusercontent.com/cyber-dojo/versioner/master
  export $(curl "${VERSIONER_URL}/app/.env")
  local -r CYBER_DOJO_RUNNER_TAG="${CIRCLE_SHA1:0:7}"

  # Ensure merkely_fingerprint() works
  docker pull ${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}

	docker run \
      --env MERKELY_COMMAND=log_deployment \
      --env MERKELY_OWNER=${MERKELY_OWNER} \
      --env MERKELY_PIPELINE=${MERKELY_PIPELINE} \
      --env MERKELY_FINGERPRINT=$(merkely_fingerprint) \
      --env MERKELY_DESCRIPTION="Deployed to ${environment} in circleci pipeline" \
      --env MERKELY_ENVIRONMENT="${MERKELY_ENVIRONMENT}" \
      --env MERKELY_CI_BUILD_URL=${CIRCLE_BUILD_URL} \
      --env MERKELY_API_TOKEN=${MERKELY_API_TOKEN} \
      --env MERKELY_HOST="${MERKELY_HOST}" \
      --rm \
      --volume /var/run/docker.sock:/var/run/docker.sock \
    	    merkely/change:latest
}

# - - - - - - - - - - - - - - - - - - -
merkely_fingerprint()
{
  echo "docker://${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}"
}
