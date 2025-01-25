#!/usr/bin/env bash
set -Ee

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

readonly DEMO_FILENAME="/tmp/runner_demo.html"

source "${ROOT_DIR}/bin/lib.sh"
export $(echo_env_vars)
docker compose --progress=plain up --wait --wait-timeout=10 client
docker exec -it test_runner_client ruby /runner/demo.rb > "${DEMO_FILENAME}"
open "file://${DEMO_FILENAME}"
