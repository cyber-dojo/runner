#!/bin/bash -Eeu

# - - - - - - - - - - - - - - - - - - - - - - - -
pull_dependent_images()
{
  echo
  echo Pulling images used in server-side tests
  # alpine:latest is used for tests showing bash must be in the image_name
  echo alpine:latest
  docker pull alpine:latest

  local -r display_names="$(
    docker run \
      --entrypoint='' \
      --rm \
      --volume ${ROOT_DIR}/test:/test/:ro \
        ${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG} \
          ruby /test/dependent_display_names.rb)"

  echo "${display_names}" \
    | while read display_name
      do
        local json="$(json_data "${display_name}")"
        local manifest="$(curl \
          --data "${json}" \
          --silent \
          -X GET \
          "http://$(ip_address):$(lsp_port)/manifest")"

        local image_name=$(echo "${manifest}" | jq --raw-output '.manifest.image_name')

        echo "${image_name}"
        docker pull "${image_name}"
      done

  echo
  echo Removing image pulled in client-side test
  echo busybox:glibc
  docker image rm busybox:glibc &> /dev/null || true
}

# - - - - - - - - - - - - - - - - - - - - - - - -
ip_address()
{
  if [ -n "${DOCKER_MACHINE_NAME:-}" ]; then
    docker-machine ip ${DOCKER_MACHINE_NAME}
  else
    echo localhost
  fi
}

# - - - - - - - - - - - - - - - - - - - - - - - -
json_data()
{
  local -r display_name="${1}"
  cat <<- EOF
  { "name":"${display_name}" }
EOF
}

# - - - - - - - - - - - - - - - - - - - - - - - -
lsp_port()
{
  echo "${CYBER_DOJO_LANGUAGES_START_POINTS_PORT}"
}
