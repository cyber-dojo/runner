#!/usr/bin/env bash
set -euo pipefail

export KOSLI_HOST=https://staging.app.kosli.com
export KOSLI_ORG=cyber-dojo
export KOSLI_API_TOKEN=dummy-read-only
export KOSLI_FLOW=snyk-vulns-build
export KOSLI_FINGERPRINT=922ee4faefd82c95bebe9b55f3e00a9eba5c2023377e57b9771d431f5cfd7949

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TRAIL_NAMES_FILE="${SCRIPT_DIR}/trail_names.json"
POLICY_FILE="${SCRIPT_DIR}/snyk-vuln-compliance.rego"

readarray -t trail_names < <(jq -r '.[]' "${TRAIL_NAMES_FILE}")

TRAIL_NAMES_JSON="$(cat "${TRAIL_NAMES_FILE}")"
TRAIL_NAMES="$(jq --raw-output '. | join(" ")' <<< "${TRAIL_NAMES_JSON}")"

TRAIL_NAME1=runner-high-SNYK-GOLANG-GITHUBCOMGOJOSEGOJOSEV4-15875221
TRAIL_NAME2=runner-critical-SNYK-GOLANG-GOOGLEGOLANGORGGRPC-15691172

kosli evaluate trails \
  --attestations snyk \
  --output json \
  --policy "${POLICY_FILE}" \
  ${TRAIL_NAMES}

# kosli evaluate trails \
#   --attestations snyk \
#   --output json \
#   --policy "${POLICY_FILE}" \
#   --show-input \
#   ${TRAIL_NAME1}

