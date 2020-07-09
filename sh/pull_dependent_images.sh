#!/bin/bash -Eeu

# - - - - - - - - - - - - - - - - - - - - - - - -
pull_dependent_images()
{
  echo
  echo Pulling images required for server-side tests
  docker exec test-runner-server ruby /test/pull_images.rb
  docker image rm busybox:glibc &> /dev/null || true
}

# - - - - - - - - - - - - - - - - - - - - - - - -
pull_dependent_images
