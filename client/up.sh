#!/bin/bash -Eeu

# Note that the --host is needed for IPv4 and IPv6 addresses

rackup \
  --warn \
  --host 0.0.0.0 \
  --port ${PORT} \
  --server thin \
  --env production \
    config.ru
