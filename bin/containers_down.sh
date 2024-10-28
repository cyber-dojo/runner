#!/usr/bin/env bash
set -Eeu

# - - - - - - - - - - - - - - - - - - -
containers_down()
{
  docker compose \
    down \
    --remove-orphans \
    --volumes
}
