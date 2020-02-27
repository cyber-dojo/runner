#!/bin/bash -Eeu

readonly MY_DIR="$( cd "$(dirname "${0}")" && pwd )"

export RUBYOPT='-W2'

rackup \
  --warn \
  --port ${PORT} \
  --server thin \
  --env production \
    ${MY_DIR}/config.ru
