#!/bin/bash

# Sticky bit must be set on /tmp otherwise
# runner.rb's Dir.mktmpdir(nil,'/tmp') complains
# that it is world writable but not sticky,
# and the tar-pipes fail.
chmod 1777 /tmp

rackup             \
  --env production \
  --host 0.0.0.0   \
  --port 4597      \
  --server thin    \
  --warn           \
    config.ru
