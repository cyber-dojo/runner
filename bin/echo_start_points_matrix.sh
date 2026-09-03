#!/usr/bin/env bash
set -Eeu

export ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/bin/lib.sh"

show_help()
{
    local -r MY_NAME=$(basename "${BASH_SOURCE[0]}")
    cat <<- EOF

    Use: bin/${MY_NAME} <TAGGED_FILE> [NAME...]

    Echoes the lines of <TAGGED_FILE> as a one-line JSON array, ready to be
    read as a GitHub Actions matrix. Each entry holds one start-point at the
    commit the file pins:
      tagged_url  the <TAG>@<URL> that bin/test_one_start_point.sh takes
      name        names the matrix job, which a whole tagged_url reads badly as

    <TAGGED_FILE> is the git_repo_urls.tagged file from
    https://github.com/cyber-dojo/languages-start-points

    NAME... limits the array to those start-points, eg java-junit. Given none,
    every line is used.

    Options:
      -h    Show this help

    Example:
      bin/${MY_NAME} git_repo_urls.tagged java-junit ruby-minitest | jq .
      [
        {
          "name": "java-junit",
          "tagged_url": "b61527f@https://github.com/cyber-dojo-start-points/java-junit"
        },
        {
          "name": "ruby-minitest",
          "tagged_url": "6d16472@https://github.com/cyber-dojo-start-points/ruby-minitest"
        }
      ]

EOF
}

check_args()
{
  case "${1:-}" in
    '-h' | '--help')
      show_help
      exit 0
      ;;
    '')
      show_help
      stderr "no argument - must be the name of a git_repo_urls.tagged file"
      exit_non_zero
      ;;
  esac
}

# Echoes the <TAG>@<URL> lines of ${filename} as a JSON array of
# {name,tagged_url} objects, keeping only those whose start-point name is in
# ${names}, or all of them when it is empty. A name is the last path segment
# of the URL, which is what the cyber-dojo-start-points repo is called.
echo_start_points_matrix()
{
  local -r filename="${1}"
  shift

  jq --raw-input --slurp --compact-output --args '
    $ARGS.positional as $names
    | split("\n")
    | map(select(length > 0))
    | map({name: sub(".*/"; ""), tagged_url: .})
    | map(select(($names | length) == 0 or (.name as $n | $names | index($n))))
  ' "$@" < "${filename}"
}

if [ "${0}" = "${BASH_SOURCE[0]}" ]; then
  check_args "$@"
  exit_non_zero_unless_installed jq
  readonly TAGGED_FILE="${1}"
  shift
  exit_non_zero_unless_file_exists "${TAGGED_FILE}"
  readonly MATRIX="$(echo_start_points_matrix "${TAGGED_FILE}" "$@")"
  # An empty matrix fails the workflow with a message about the matrix rather
  # than about the names, so a misspelled name is named here instead.
  if [ "${MATRIX}" == '[]' ]; then
    stderr "no start-points in ${TAGGED_FILE} match: $*"
    exit_non_zero
  fi
  echo "${MATRIX}"
fi
