#!/bin/bash -Eeu

# - - - - - - - - - - - - - - - - - - -
containers_down()
{
  augmented_docker_compose \
    down \
    --remove-orphans \
    --volumes
}
