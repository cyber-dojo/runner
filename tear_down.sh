#!/bin/bash

# During development, when a test fails it can leave containers around.
# I'd like to leave the container for a failed test unremoved since that way
# I can shell into it (eg for debugging). So I don't do a teardown at the
# end of each test. Instead I do a big teardown before all the tests run.

readonly UNDEADS=$(docker ps --all --filter "name=test_run__runner_stateless_" --format "{{.Names}}")
if [ "${UNDEADS}" != "" ]; then
  docker rm --force ${UNDEADS}
fi
