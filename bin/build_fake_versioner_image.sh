#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"
source "${ROOT_DIR}/bin/echo_env_vars.sh"

readonly FAKE_IMAGE=cyberdojo/versioner:latest

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: bin/${MY_NAME}

    Builds a stub ${FAKE_IMAGE} image serving this repo's
    runner image and tag in place of the released ones. Every other env-var
    is copied from the released image.

    The scripts a start-point's run_tests.sh curls from
    cyber-dojo-start-points/shared-scripts start their runner as
    \${CYBER_DOJO_RUNNER_IMAGE}:\${CYBER_DOJO_RUNNER_TAG}, read from
    ${FAKE_IMAGE}. Overwriting that tag is what points them
    at the runner image built here rather than the released one.

    Options:
      -h    Show this help

    Example:
      bin/${MY_NAME}

EOF
}

check_args()
{
  case "${1:-}" in
    '-h' | '--help')
      show_help
      exit 0
      ;;
    '')
      ;;
    *)
      show_help
      stderr "argument is '${1}' - this script takes no arguments"
      exit_non_zero
      ;;
  esac
}

# Echoes the env-vars of the released image. Called before the tag is
# overwritten, so the stub inherits every var it does not itself set.
# Reading it afterwards would read the stub.
released_env_vars()
{
  docker run --rm "${FAKE_IMAGE}" 2> /dev/null
}

# Echoes ${env_vars} with ${name} set to ${value}. The name is anchored so
# CYBER_DOJO_RUNNER_IMAGE cannot also match CYBER_DOJO_RUNNER_IMAGE_SOMETHING.
replace_with()
{
  local -r env_vars="${1}"
  local -r name="${2}"
  local -r value="${3}"
  local -r all_except=$(echo "${env_vars}" | grep --invert-match "^${name}=")
  printf "%s\n%s=%s\n" "${all_except}" "${name}" "${value}"
}

# Exits non-zero unless the two values match, naming ${message} when they do not.
assert_equal()
{
  local -r expected="${1}"
  local -r actual="${2}"
  local -r message="${3}"
  if [ "${expected}" == "${actual}" ]; then
    echo "asserted: '${expected}'"
  else
    stderr "assert_equal failed: ${message}"
    stderr "expected: '${expected}'"
    stderr "  actual: '${actual}'"
    exit_non_zero
  fi
}

# Builds the stub image and checks it serves the runner identity of this repo.
build_fake_versioner_image()
{
  local -r tmp_dir="$(mktemp -d /tmp/cyber-dojo-runner-fake-versioner.XXXXXX)"

  local env_vars="$(released_env_vars)"
  env_vars=$(replace_with "${env_vars}" CYBER_DOJO_RUNNER_IMAGE "${CYBER_DOJO_RUNNER_IMAGE}")
  env_vars=$(replace_with "${env_vars}" CYBER_DOJO_RUNNER_SHA   "${CYBER_DOJO_RUNNER_SHA}")
  env_vars=$(replace_with "${env_vars}" CYBER_DOJO_RUNNER_TAG   "${CYBER_DOJO_RUNNER_TAG}")

  echo "${env_vars}" > "${tmp_dir}/.env"

  # The cyber-dojo script and commander's cat-start-point-create.sh both read
  # the env-vars with 'docker run --entrypoint=cat ... /app/.env', so the file
  # has to sit at that path and be what the default entrypoint prints.
  {
    echo 'FROM alpine:latest'
    echo 'COPY . /app'
    echo 'ARG SHA'
    echo 'ENV SHA=${SHA}'
    echo 'ARG RELEASE'
    echo 'ENV RELEASE=${RELEASE}'
    echo 'ENTRYPOINT [ "cat", "/app/.env" ]'
  } > "${tmp_dir}/Dockerfile"

  docker build \
    --build-arg SHA="${CYBER_DOJO_RUNNER_SHA}" \
    --build-arg RELEASE=999.999.999 \
    --tag "${FAKE_IMAGE}" \
    "${tmp_dir}"

  rm -rf "${tmp_dir}"

  echo "Checking fake ${FAKE_IMAGE}"

  local expected
  local actual

  expected="CYBER_DOJO_RUNNER_IMAGE=${CYBER_DOJO_RUNNER_IMAGE}"
  actual=$(docker run --rm "${FAKE_IMAGE}" | grep '^CYBER_DOJO_RUNNER_IMAGE=')
  assert_equal "${expected}" "${actual}" CYBER_DOJO_RUNNER_IMAGE

  expected="CYBER_DOJO_RUNNER_SHA=${CYBER_DOJO_RUNNER_SHA}"
  actual=$(docker run --rm "${FAKE_IMAGE}" | grep '^CYBER_DOJO_RUNNER_SHA=')
  assert_equal "${expected}" "${actual}" CYBER_DOJO_RUNNER_SHA

  expected="CYBER_DOJO_RUNNER_TAG=${CYBER_DOJO_RUNNER_TAG}"
  actual=$(docker run --rm "${FAKE_IMAGE}" | grep '^CYBER_DOJO_RUNNER_TAG=')
  assert_equal "${expected}" "${actual}" CYBER_DOJO_RUNNER_TAG

  # The start-point's runner container is created from this name:tag, so a
  # missing image here would surface much later as a failed readiness check.
  local -r tagged_name="${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}"
  if [ -z "$(docker image ls --quiet "${tagged_name}")" ]; then
    stderr "${tagged_name} is not in the local docker image store"
    exit_non_zero
  fi
  echo "Found ${tagged_name}"
}

if [ "${0}" = "${BASH_SOURCE[0]}" ]; then
  check_args "$@"
  exit_non_zero_unless_installed docker git
  # shellcheck disable=SC2046
  export $(echo_env_vars)
  build_fake_versioner_image
fi
