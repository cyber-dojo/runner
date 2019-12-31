#!/bin/bash -Ee

# - - - - - - - - - - - - - - - - - - - - - - - -
on_ci()
{
  [ -n "${CIRCLECI}" ]
}

# - - - - - - - - - - - - - - - - - - - - - - - -
on_ci_pull_dependent_images()
{
  if ! on_ci; then
    echo 'not on CI so not pulling dependent images'
    return
  fi
  echo 'on CI so pulling dependent images'
  # to avoid pulls happening in speed tests
  docker pull cyberdojofoundation/gcc_assert
  docker pull cyberdojofoundation/csharp_nunit
  docker pull cyberdojofoundation/python_pytest
  docker pull cyberdojofoundation/clang_assert
  docker pull cyberdojofoundation/perl_test_simple
}

# - - - - - - - - - - - - - - - - - - - - - - - -
on_ci_pull_dependent_images
