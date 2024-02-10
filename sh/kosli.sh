#!/usr/bin/env bash
set -Eeu

export KOSLI_ORG=cyber-dojo
export KOSLI_FLOW=runner-ci
export KOSLI_TRAIL="${GITHUB_SHA}"

# KOSLI_ORG is set in CI
# KOSLI_API_TOKEN is set in CI
# KOSLI_API_TOKEN_STAGING is set in CI
# KOSLI_HOST_STAGING is set in CI
# KOSLI_HOST_PRODUCTION is set in CI
# SNYK_TOKEN is set in CI

# - - - - - - - - - - - - - - - - - - -
kosli_begin_trail()
{
  local -r hostname="${1}"
  local -r api_token="${2}"

  kosli create flow "${KOSLI_FLOW}" \
    --description="Test runner" \
    --host="${hostname}" \
    --api-token="${api_token}" \
    --template-file="$(repo_root)/.kosli.yml" \
    --visibility=public

  kosli begin trail "${KOSLI_TRAIL}" \
    --host="${hostname}" \
    --api-token="${api_token}"
}

# - - - - - - - - - - - - - - - - - - -
kosli_attest_artifact()
{
  local -r hostname="${1}"
  local -r api_token="${2}"

  pushd "$(repo_root)" > /dev/null

  kosli attest artifact "$(artifact_name)" \
    --artifact-type=docker \
    --host="${hostname}" \
    --api-token="${api_token}" \
    --name=exercises-start-points \
    --name=runner

  popd > /dev/null
}

# - - - - - - - - - - - - - - - - - - -
kosli_attest_coverage_evidence()
{
  local -r hostname="${1}"
  local -r api_token="${2}"

  kosli attest generic $(artifact_name) \
    --artifact-type=docker \
    --description="server & client branch-coverage reports" \
    --name=runner.branch-coverage \
    --host="${hostname}" \
    --api-token="${api_token}" \
    --user-data="$(evidence_json_path)"
}

# - - - - - - - - - - - - - - - - - - -
kosli_attest_snyk_evidence()
{
  local -r hostname="${1}"
  local -r api_token="${2}"

  kosli attest snyk "$(artifact_name)" \
    --artifact-type=docker \
    --host="${hostname}" \
    --api-token="${api_token}" \
    --name=runner.snyk-scan \
    --scan-results="$(repo_root)/snyk.json"
}

# - - - - - - - - - - - - - - - - - - -
kosli_assert_artifact()
{
  local -r hostname="${1}"
  local -r api_token="${2}"

  kosli assert artifact "$(artifact_name)" \
    --artifact-type=docker \
    --host="${hostname}" \
    --api-token="${api_token}"
}

# - - - - - - - - - - - - - - - - - - -
on_ci_kosli_begin_trail()
{
  if on_ci; then
    kosli_begin_trail "${KOSLI_HOST_STAGING}"    "${KOSLI_API_TOKEN_STAGING}"
    kosli_begin_trail "${KOSLI_HOST_PRODUCTION}" "${KOSLI_API_TOKEN}"
  fi
}

# - - - - - - - - - - - - - - - - - - -
on_ci_kosli_attest_artifact()
{
  if on_ci; then
    kosli_attest_artifact "${KOSLI_HOST_STAGING}"    "${KOSLI_API_TOKEN_STAGING}"
    kosli_attest_artifact "${KOSLI_HOST_PRODUCTION}" "${KOSLI_API_TOKEN}"
  fi
}

# - - - - - - - - - - - - - - - - - - -
on_ci_kosli_attest_coverage_evidence()
{
  if on_ci; then
    write_evidence_json
    kosli_attest_coverage_evidence "${KOSLI_HOST_STAGING}"    "${KOSLI_API_TOKEN_STAGING}"
    kosli_attest_coverage_evidence "${KOSLI_HOST_PRODUCTION}" "${KOSLI_API_TOKEN}"
  fi
}

# - - - - - - - - - - - - - - - - - - -
on_ci_kosli_attest_snyk_scan_evidence()
{
  if on_ci; then
    set +e
    snyk container test "$(artifact_name)" \
      --json-file-output="$(repo_root)/snyk.json" \
      --policy-path="$(repo_root)/.snyk"
    set -e

    kosli_attest_snyk_evidence "${KOSLI_HOST_STAGING}"    "${KOSLI_API_TOKEN_STAGING}"
    kosli_attest_snyk_evidence "${KOSLI_HOST_PRODUCTION}" "${KOSLI_API_TOKEN}"
  fi
}

# - - - - - - - - - - - - - - - - - - -
on_ci_kosli_assert_artifact()
{
  if on_ci; then
    kosli_assert_artifact "${KOSLI_HOST_STAGING}"    "${KOSLI_API_TOKEN_STAGING}"
    kosli_assert_artifact "${KOSLI_HOST_PRODUCTION}" "${KOSLI_API_TOKEN}"
  fi
}

# - - - - - - - - - - - - - - - - - - -
artifact_name()
{
  source "$(repo_root)/sh/echo_versioner_env_vars.sh"
  export $(echo_versioner_env_vars)
  echo "${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}"
}

# - - - - - - - - - - - - - - - - - - -
write_evidence_json()
{
  {
    echo '{ "server": '
    cat "$(repo_root)/test/server/reports/coverage.json"
    echo ', "client": '
    cat "$(repo_root)/test/client/reports/coverage.json"
    echo '}'
  } > "$(evidence_json_path)"
}

# - - - - - - - - - - - - - - - - - - -
evidence_json_path()
{
  echo "$(repo_root)/test/evidence.json"
}

# - - - - - - - - - - - - - - - - - - - - - - - -
on_ci()
{
  [ -n "${CI:-}" ]
}

# - - - - - - - - - - - - - - - - - - - - - - - -
repo_root()
{
  git rev-parse --show-toplevel
}

export -f repo_root
