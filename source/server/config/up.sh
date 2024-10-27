#!/bin/bash -Eeu

#readonly PORT="${CYBER_DOJO_K8S_PORT:-${CYBER_DOJO_RUNNER_PORT}}"
readonly PORT="${CYBER_DOJO_RUNNER_PORT}"
readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export RUBYOPT='-W2'

puma \
  --port=${PORT} \
  --config=${MY_DIR}/puma.rb
