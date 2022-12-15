#!/bin/bash -Eeu

# ROOT_DIR must be set

export KOSLI_OWNER=cyber-dojo
export KOSLI_PIPELINE=runner

readonly KOSLI_HOST_STAGING=https://staging.app.kosli.com
readonly KOSLI_HOST_PRODUCTION=https://app.kosli.com

# - - - - - - - - - - - - - - - - - - -
kosli_declare_pipeline()
{
  local -r hostname="${1}"

    kosli pipeline declare \
    --description "Test runner" \
    --visibility public \
    --template artifact,branch-coverage \
    --host "${hostname}"
}

# - - - - - - - - - - - - - - - - - - -
kosli_log_artifact()
{
  local -r hostname="${1}"

  cd "$(root_dir)"

  kosli pipeline artifact report creation \
    "$(artifact_name)" \
      --artifact-type docker \
      --host "${hostname}"
}

# - - - - - - - - - - - - - - - - - - -
kosli_log_evidence()
{
  local -r hostname="${1}"

  kosli pipeline artifact report evidence generic $(artifact_name) \
    --artifact-type docker \
    --description "server & client branch-coverage reports" \
    --evidence-type branch-coverage \
    --host "${1}" \
    --user-data "$(evidence_json_path)"
}

# - - - - - - - - - - - - - - - - - - -
write_evidence_json()
{
  echo '{ "server": ' > "$(evidence_json_path)"
  cat "$(root_dir)/test/server/reports/coverage.json" >> "$(evidence_json_path)"
  echo ', "client": ' >> "$(evidence_json_path)"
  cat "$(root_dir)/test/client/reports/coverage.json" >> "$(evidence_json_path)"
  echo '}' >> "$(evidence_json_path)"
}

# - - - - - - - - - - - - - - - - - - -
evidence_json_path()
{
  echo "$(root_dir)/test/evidence.json"
}

# - - - - - - - - - - - - - - - - - - - - - - - -
on_ci()
{
  [ -n "${CI:-}" ]
}

# - - - - - - - - - - - - - - - - - - -
on_ci_kosli_declare_pipeline()
{
  if ! on_ci ; then
    return
  fi
  kosli_declare_pipeline "${KOSLI_HOST_STAGING}"
  kosli_declare_pipeline "${KOSLI_HOST_PRODUCTION}"
}

# - - - - - - - - - - - - - - - - - - -
on_ci_kosli_log_artifact()
{
  if ! on_ci ; then
    return
  fi
  kosli_log_artifact "${KOSLI_HOST_STAGING}"
  kosli_log_artifact "${KOSLI_HOST_PRODUCTION}"
}

# - - - - - - - - - - - - - - - - - - -
on_ci_kosli_log_evidence()
{
  if ! on_ci ; then
    return
  fi
  write_evidence_json
  kosli_log_evidence "${KOSLI_STAGING_HOSTNAME}"
  kosli_log_evidence "${KOSLI_PROD_HOSTNAME}"
}

# - - - - - - - - - - - - - - - - - - -
kosli_assert_artifact()
{
  local -r hostname="${1}"

  kosli assert artifact \
    "$(artifact_name)" \
      --artifact-type docker \
      --host "${hostname}"
}

# - - - - - - - - - - - - - - - - - - -
kosli_expect_deployment()
{
  local -r environment="${1}"
  local -r hostname="${2}"

  # In .github/workflows/main.yml deployment is its own job
  # and the image must be present to get its sha256 fingerprint.
  docker pull "$(artifact_name)"

  kosli expect deployment \
    "$(artifact_name)" \
    --artifact-type docker \
    --description "Deployed to ${environment} in Github Actions pipeline" \
    --environment "${environment}" \
    --host "${hostname}"
}

# - - - - - - - - - - - - - - - - - - -
artifact_name() {
  source "$(root_dir)/sh/echo_versioner_env_vars.sh"
  export $(echo_versioner_env_vars)
  echo "${CYBER_DOJO_RUNNER_IMAGE}:${CYBER_DOJO_RUNNER_TAG}"
}

# - - - - - - - - - - - - - - - - - - -
root_dir()
{
  # Functions in this file are called after sourcing (not including)
  # this file so root_dir() cannot use the path of this script.
  git rev-parse --show-toplevel
}

# - - - - - - - - - - - - - - - - - - -
on_ci_kosli_assert_artifact()
{
  if ! on_ci ; then
    return
  fi
  kosli_assert_artifact "${KOSLI_HOST_STAGING}"
  kosli_assert_artifact "${KOSLI_HOST_PRODUCTION}"
}
