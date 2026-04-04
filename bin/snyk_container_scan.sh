#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"
source "${ROOT_DIR}/bin/echo_env_vars.sh"
# shellcheck disable=SC2046
export $(echo_env_vars)

readonly IMAGE_NAME="${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}"
readonly SARIF_FILENAME=${SARIF_FILENAME:-snyk.container.scan.json}

exit_non_zero_unless_installed snyk

snyk container test "${IMAGE_NAME}" \
  --policy-path="${ROOT_DIR}/.snyk" \
  --sarif \
  --sarif-file-output="${ROOT_DIR}/${SARIF_FILENAME}" | /tmp/snyk.log

EXIT_CODE=${PIPESTATUS[0]}

if [ grep Forbidden /tmp/snyk.log ]; then
  >&2 echo FAILED: snyk container test ...
  EXIT_CODE=42
fi

echo "EXIT_CODE=:${EXIT_CODE}:"
exit ${EXIT_CODE}
