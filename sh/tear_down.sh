#!/bin/bash

# During development, when a test fails it can very occasionally leave a
# containers around. I leave such containers un-removed since that way
# I can shell into it (eg for debugging). So I don't do a teardown at the
# end of each test. Instead I do a big teardown before all the tests run.

readonly PREFIX='cyber_dojo_runner'

readonly ZOMBIE_CONTAINERS=$(docker ps --all --filter "name=${PREFIX}" --format "{{.Names}}")

if [ "${ZOMBIE_CONTAINERS}" != "" ]; then
  docker rm --force "${ZOMBIE_CONTAINERS}"
fi
