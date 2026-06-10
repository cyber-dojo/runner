#!/usr/bin/env bash
set -Ee

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"
source "${ROOT_DIR}/bin/echo_env_vars.sh"
# shellcheck disable=SC2046
export $(echo_env_vars)

# Run this demo as its own docker-compose project so several demos (in this
# repo and in sibling repos) can run at once without their container names or
# networks colliding. Override to run a second runner demo alongside the first.
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-runner}"

readonly DEMO_FILENAME="/tmp/runner_demo.html"

docker compose --progress=plain up --wait --wait-timeout=10 client
docker exec -it "$(service_container client)" ruby /runner/demo.rb > "${DEMO_FILENAME}"
open "file://${DEMO_FILENAME}"
