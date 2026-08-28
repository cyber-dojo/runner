#!/usr/bin/env bash
set -Eeu

exit_non_zero_unless_installed()
{
  for dependent in "$@"; do
    if ! installed "${dependent}" ; then
      stderr "${dependent} is not installed!"
      if [ "${dependent}" == snyk ]; then
        stderr "On a Mac you can install with:"
        stderr "  brew tap snyk/tap"
        stderr "  brew install snyk-cli"
      fi
      exit_non_zero
    fi
  done
}

installed()
{
  if hash "${1}" &> /dev/null; then
    true
  else
    false
  fi
}

service_container()
{
  # Echo the container id of the given docker-compose service within this
  # demo/test's project. The project is COMPOSE_PROJECT_NAME (set by
  # bin/demo.sh and bin/run_tests.sh), defaulting to runner so the helpers
  # work against a plain run when the var is not exported in the shell.
  # Resolving by compose label (not a fixed container_name) lets several
  # demos/tests, here and in sibling repos, run at once without colliding.
  local -r service="${1}"
  docker ps \
    --filter "label=com.docker.compose.project=${COMPOSE_PROJECT_NAME:-runner}" \
    --filter "label=com.docker.compose.service=${service}" \
    --format '{{.ID}}'
}

stderr()
{
  local -r message="${1}"
  >&2 echo "ERROR: ${message}"
}

exit_non_zero_unless_file_exists()
{
  local -r filename="${1}"
  if [ ! -f "${filename}" ]; then
    stderr "${filename} does not exist"
    exit_non_zero
  fi
}

exit_non_zero()
{
  exit 42
}

abs_filename()
{
  echo "$(cd "$(dirname "${1}")" && pwd)/$(basename "${1}")"
}

containers_down()
{
  docker compose down --remove-orphans --volumes
}

remove_old_images()
{
  echo Removing old images
  # grep exits non-zero when the machine holds no runner image, eg one whose
  # images have just been cleared, so an empty list must not end the build.
  local -r dil=$(docker image ls --format "{{.Repository}}:{{.Tag}}" | grep runner || true)
  remove_all_but_current "${dil}" "${CYBER_DOJO_RUNNER_CLIENT_IMAGE}"
  remove_all_but_current "${dil}" "${CYBER_DOJO_RUNNER_IMAGE}"
  remove_all_but_current "${dil}" cyberdojo/runner
}

# Keeps this commit's tag, which names the build just made. Every older tag
# goes, and an earlier build whose last tag was one of those goes with it.
remove_all_but_current()
{
  local -r docker_image_ls="${1}"
  local -r name="${2}"
  # Its own name, not image_name: bash locals are dynamically scoped, and
  # build_image declares image_name readonly before calling this.
  local tagged_name
  for tagged_name in $(echo "${docker_image_ls}" | grep "${name}:" || true)
  do
    if [ "${tagged_name}" != "${name}:${CYBER_DOJO_RUNNER_TAG}" ]; then
      # Best-effort: an image still referenced by a container from another
      # compose project (eg creator-runner-1) cannot be removed. Skip it rather
      # than aborting the whole build under set -Eeu; it will be cleaned by a
      # later build once nothing is using it.
      docker image rm --force "${tagged_name}" || echo "  skipped ${tagged_name} (in use)"
    fi
  done
}

echo_warnings()
{
  local -r SERVICE_NAME="${1}" # {client|server}
  local -r DOCKER_LOG=$(docker logs "${CONTAINER_NAME}" 2>&1)
  # Handle known warnings (eg waiting on Gem upgrade)
  # local -r SHADOW_WARNING="server.rb:(.*): warning: shadowing outer local variable - filename"
  # DOCKER_LOG=$(strip_known_warning "${DOCKER_LOG}" "${SHADOW_WARNING}")

  if echo "${DOCKER_LOG}" | grep --quiet "warning" ; then
    echo "Warnings in ${SERVICE_NAME} container"
    echo "${DOCKER_LOG}"
  fi
}

strip_known_warning()
{
  local -r DOCKER_LOG="${1}"
  local -r KNOWN_WARNING="${2}"
  local -r STRIPPED=$(echo -n "${DOCKER_LOG}" | grep --invert-match -E "${KNOWN_WARNING}")
  if [ "${DOCKER_LOG}" != "${STRIPPED}" ]; then
    echo "Known service start-up warning found: ${KNOWN_WARNING}"
  else
    echo "Known service start-up warning NOT found: ${KNOWN_WARNING}"
    exit_non_zero
  fi
  echo "${STRIPPED}"
}
