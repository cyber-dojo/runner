#!/usr/bin/env bash
set -Eeu

# cyberdojo/service-yaml image lives at
# https://github.com/cyber-dojo-tools/service-yaml

# The initial change-directory command is needed because
# the current working directory is taken as the dir for
# relative pathnames (eg in volume-mounts) when the
# yml is received from stdin (--file -).

# - - - - - - - - - - - - - - - - - - -
augmented_docker_compose()
{
  cd "${ROOT_DIR}" && cat "./docker-compose.yml" \
    | docker run --rm --interactive cyberdojo/service-yaml \
        languages-start-points \
    | tee /tmp/augmented-docker-compose.runner.peek.yml \
    | docker-compose \
        --project-name cyber-dojo \
        --file -                  \
        "$@"
}
