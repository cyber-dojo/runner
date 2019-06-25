#!/bin/bash

export RUBYOPT=-w

rackup             \
  --env production \
  --host 0.0.0.0   \
  --port 4597      \
  --server thin    \
  --warn           \
    config.ru
