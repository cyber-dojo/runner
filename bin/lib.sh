#!/usr/bin/env bash
set -Eeu

exit_non_zero_unless_file_exists()
{
  local -r filename="${1}"
  if [ ! -f "${filename}" ]; then
    echo "ERROR: ${filename} does not exist"
    exit 42
  fi
}

abs_filename()
{
  echo "$(cd "$(dirname "${1}")" && pwd)/$(basename "${1}")"
}
