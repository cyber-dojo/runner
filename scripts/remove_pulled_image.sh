#!/bin/bash -Eeu

# - - - - - - - - - - - - - - - - - - - - - - - -
remove_pulled_image()
{
  echo
  echo Removing image pulled in client-side test
  echo busybox:glibc
  docker image rm busybox:glibc &> /dev/null || true
}
