#!/bin/bash -Eeu

# - - - - - - - - - - - - - - - - - - - - - - - -
on_ci()
{
  [ -n "${CIRCLECI:-}" ]
}

# - - - - - - - - - - - - - - - - - - - - - - - -
on_ci_pull_dependent_images()
{
  if ! on_ci; then
    echo 'not on CI so not pulling dependent images'
    return
  fi
  echo 'on CI so pulling dependent images'
  # eg, to avoid pulls happening in speed tests
  docker pull cyberdojo/check-test-results
  docker exec test-runner-server ruby /test/pull_images.rb
}

# - - - - - - - - - - - - - - - - - - - - - - - -
on_ci_pull_dependent_images
