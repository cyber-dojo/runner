#!/bin/bash
set -e

# HOME=/tmp is needed to avoid warnings such as
#   Bundler will use `/tmp/bundler/home/unknown' as your home directory temporarily
# This is important for tests that assert on container log contents at startup.

# --host is needed for IPv4 and IPv6 addresses

HOME=/tmp bundle exec rackup \
  --warn           \
  --host 0.0.0.0   \
  --port 4597      \
  --server thin    \
  --env production \
    config.ru
