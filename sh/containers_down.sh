#!/bin/bash -Eeu

# - - - - - - - - - - - - - - - - - - - - - - - - - -
containers_down()
{
  echo
  docker-compose \
    --file "${ROOT_DIR}/docker-compose.yml" \
    stop \
    --timeout 1

  #sleep 2
  #echo
  #docker logs test-runner-client 2>&1 | grep "Goodbye from runner client"
  #docker logs test-runner-server 2>&1 | grep "Goodbye from runner server"

  echo
  docker-compose \
    --file "${ROOT_DIR}/docker-compose.yml" \
    down \
    --remove-orphans \
    --volumes
}
