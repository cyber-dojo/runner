#!/bin/bash

export RUBYOPT='-W2'

rackup \
  --env production  \
  --port 4597       \
  --server thin     \
  --warn            \
    config.ru
