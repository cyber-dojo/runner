#!/usr/bin/env bash
set -Eeu

# - - - - - - - - - - - - - - - - - - -
containers_down()
{
  augmented_docker_compose \
    down \
    --remove-orphans \
    --volumes
}
