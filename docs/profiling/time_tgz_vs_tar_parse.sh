#!/usr/bin/env bash
set -Eeu -o pipefail
# Supplies time_tgz_vs_tar_parse.rb with payloads and a ruby to measure in.
#
# The payloads are built in a language image by the same rule as
# time_tgz_vs_tar_emit.sh uses, so the two halves of the gzip question are
# measured over the same bytes and their costs can be added.
#
# The ruby runs in a stock ruby image rather than the runner image, because the
# runner image is amd64 and would be emulated on an arm64 host, inflating the
# Zlib inflate that is the thing being measured.

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd "${MY_DIR}/../.." && pwd)"
source "${MY_DIR}/probe_lib.sh"

probe_help_check "${1:-}" \
"Usage: docs/profiling/time_tgz_vs_tar_parse.sh [-h] [IMAGE]

Times TGZ.files(tgz) against TarFile::Reader alone, over sandbox payloads
built in IMAGE, and prints the microseconds gzip adds to the runner.

Options:
  -h    Show this help

Example:
  docs/profiling/time_tgz_vs_tar_parse.sh ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd"

readonly IMAGE="${1:-ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd}"
readonly RUBY_IMAGE=ruby:3.4-alpine
readonly PAYLOAD_DIR="$(mktemp -d)"

readonly BUILDER=$(cat <<'SHELL'
set -eu
readonly CORPUS=/tmp/corpus
readonly CORPUS_KB=8192

build_corpus()
{
  find /usr /lib -name '*.py' -type f 2>/dev/null | head -n 200 | xargs cat > "${CORPUS}"
  if [ "$(stat -c %s "${CORPUS}")" -lt 1024 ]; then
    echo 'ERROR: no source text found to build a corpus from' >&2
    exit 1
  fi
  local i
  for (( i = 0; i < 20; i++ )); do
    if [ "$(stat -c %s "${CORPUS}")" -ge $(( CORPUS_KB * 1024 )) ]; then
      return
    fi
    cat "${CORPUS}" "${CORPUS}" > "${CORPUS}.2"
    mv "${CORPUS}.2" "${CORPUS}"
  done
}

build_payload()
{
  local -r name="${1}" count="${2}" size_kb="${3}"
  local i
  rm -rf /tmp/sandbox
  mkdir -p /tmp/sandbox
  for (( i = 0; i < count; i++ )); do
    dd if="${CORPUS}" of="/tmp/sandbox/file_${i}.py" \
       bs=1024 skip=$(( i * (size_kb + 7) % (CORPUS_KB - size_kb) )) count="${size_kb}" \
       status=none
  done
  tar -cf "/payload/${name}.tar" -C /tmp sandbox
}

build_corpus
build_payload typical 12  2
build_payload medium  40 10
build_payload large   16 50
build_payload ceiling 50 50
SHELL
)

probe_environment
echo "image: ${IMAGE}"
echo "ruby:  ${RUBY_IMAGE}"

docker run --rm \
  --tmpfs /tmp:exec,size=250M,mode=1777 \
  --volume "${PAYLOAD_DIR}:/payload" \
  --entrypoint='' "${IMAGE}" bash -c "${BUILDER}"

docker run --rm \
  --volume "${REPO_DIR}:/repo:ro" \
  --volume "${PAYLOAD_DIR}:/payload:ro" \
  "${RUBY_IMAGE}" \
  ruby /repo/docs/profiling/time_tgz_vs_tar_parse.rb \
    /payload/typical.tar /payload/medium.tar /payload/large.tar /payload/ceiling.tar

rm -rf "${PAYLOAD_DIR}"
