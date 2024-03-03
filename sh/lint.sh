#!/usr/bin/env bash
set -Ee

repo_root() { git rev-parse --show-toplevel; }

docker run --rm --volume "$(repo_root):/app" cyberdojo/rubocop --raise-cop-error "$@"
