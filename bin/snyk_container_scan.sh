#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"
export $(echo_versioner_env_vars)

readonly IMAGE_NAME="${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}"

snyk container test "${IMAGE_NAME}" \
  --file="${ROOT_DIR}/Dockerfile" \
  --sarif \
  --sarif-file-output="${ROOT_DIR}/snyk.container.scan.json" \
  --policy-path="${ROOT_DIR}/.snyk"
