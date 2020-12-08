#!/bin/bash -Eeu

# During development, when a test fails it can leave a container.
# I leave such containers un-removed since so I can shell into it
# (eg for debugging). So I don't do a teardown at the  end of each
# test. Instead I do a big teardown before all the tests run.

#- - - - - - - - - - - - - - - - - - - - - - - -
remove_zombie_containers()
{
  local -r PREFIX='cyber_dojo_runner'
  local -r ZOMBIE_CONTAINERS=$(docker ps --all --filter "name=${PREFIX}" --format "{{.Names}}")
  if [ "${ZOMBIE_CONTAINERS}" != "" ]; then
    echo
    echo Removing zombie containers from previous test runs...
    docker rm --force "${ZOMBIE_CONTAINERS}"
  fi
}
