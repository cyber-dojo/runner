#!/bin/bash
set -e

export RUBYOPT='-W2'

rackup \
  --env production  \
  --port 4597       \
  --server thin     \
  --warn            \
    /app/config.ru
