#!/bin/bash -Eeu

# - - - - - - - - - - - - - - - - - - - -
ip_address()
{
  if [ -n "${DOCKER_MACHINE_NAME:-}" ]; then
    docker-machine ip ${DOCKER_MACHINE_NAME}
  else
    echo localhost
  fi
}

# - - - - - - - - - - - - - - - - - - - -
wait_until_ready_and_clean()
{
  local -r name="${1}"
  local -r port="${2}"
  wait_until_ready "${name}" "${port}"
  exit_if_unclean "${name}"
}

# - - - - - - - - - - - - - - - - - - - -
wait_until_ready()
{
  local -r name="${1}"
  local -r port="${2}"
  local -r max_tries=20
  echo
  printf "Waiting until ${name} is ready"
  for _ in $(seq ${max_tries})
  do
    if ready ${port} ; then
      printf '.OK\n'
      return
    else
      printf .
      sleep 0.1
    fi
  done
  printf 'FAIL\n'
  echo "${name} not ready after ${max_tries} tries"
  if [ -f "$(ready_filename)" ]; then
    cat "$(ready_filename)"
  fi
  docker logs ${name}
  exit 42
}

# - - - - - - - - - - - - - - - - - - - -
ready()
{
  local -r port="${1}"
  local -r path=ready?
  local -r curl_cmd="curl --output $(ready_filename) --silent --fail -X GET http://$(ip_address):${port}/${path}"
  rm -f "$(ready_filename)"
  if ${curl_cmd} && [ "$(cat "$(ready_filename)")" = '{"ready?":true}' ]; then
    true
  else
    false
  fi
}

# - - - - - - - - - - - - - - - - - - - -
ready_filename()
{
  echo "${TMP_DIR}/curl.ready.output"
}

# - - - - - - - - - - - - - - - - - - - -
exit_if_unclean()
{
  local -r name="${1}"
  local log=$(docker logs "${name}" 2>&1)

  # Example of old known warnings/messages
  if [ "${name}" == test-runner-server ]; then
    local -r image_names_added_to_puller="(.*) image names added to Puller"
    log=$(strip_known_warning "${log}" "${image_names_added_to_puller}")
  fi

  local -r line_count=$(echo -n "${log}" | grep --count '^')
  echo -n "Checking ${name} started cleanly."
  # Thin=3, Unicorn=6, Puma=6
  if [ "${line_count}" == '6' ]; then
    echo OK
  else
    echo FAIL
    echo_docker_log "${name}" "${log}"
    exit 42
  fi
}

# - - - - - - - - - - - - - - - - - - - -
strip_known_warning()
{
  local -r log="${1}"
  local -r pattern="${2}"
  local -r warning=$(printf "${log}" | grep --extended-regexp "${pattern}")
  local -r stripped=$(printf "${log}" | grep --invert-match --extended-regexp "${pattern}")
  #if [ "${log}" != "${stripped}" ]; then
  #  stderr "SERVICE START-UP WARNING: ${warning}"
  #else
  #  stderr "DID _NOT_ FIND WARNING!!: ${pattern}"
  #fi
  echo "${stripped}"
}

# - - - - - - - - - - - - - - - - - - - -
echo_docker_log()
{
  local -r name="${1}"
  local -r log="${2}"
  echo "[docker logs ${name}]"
  echo "<docker_log>"
  echo "${log}"
  echo "</docker_log>"
}

# - - - - - - - - - - - - - - - - - - - -
stderr()
{
  >&2 echo "${1}"
}
