#!/usr/bin/env bash
set -Eeu

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
