#!/usr/bin/env bash
set -Eeu -o pipefail
# Measures the container half of the question "is gzip worth it?".
#
# send_tgz() in home_files.rb ends with [gzip < "${TAR_FILE}"], so every
# traffic-light compresses the whole sandbox before the runner sees a byte of
# it. The pipe is local (container -> daemon -> docker CLI -> runner), so the
# compression buys no network time; it trades container CPU, and host CPU to
# inflate it again, for fewer bytes through the daemon socket.
#
# This probe times the emit step alone. The tar file is built once per payload
# profile and reused, because building it is common to both variants and is not
# what is in question. It reports the byte counts too, since those are what a
# no-gzip variant would have to push through the socket instead.
#
# The host half of the question (Zlib inflate + untar versus untar alone) is a
# separate measurement, as is the end-to-end docker run.
#
# Payload profiles span what a kata returns: a handful of small source files at
# one end, and at the other 50 files, which is the practical ceiling, several of
# them at the 50KB per-file truncation cap.

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${MY_DIR}/probe_lib.sh"

probe_help_check "${1:-}" \
"Usage: docs/profiling/time_tgz_vs_tar_emit.sh [-h] [IMAGE]

Times [gzip < tar] against [cat tar] inside a language image, for several
sandbox payload sizes, and prints the bytes each variant emits.

Options:
  -h    Show this help

Example:
  docs/profiling/time_tgz_vs_tar_emit.sh ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd"

readonly IMAGE="${1:-ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd}"

# Mirrors the tmpfs the runner gives the container, so the tar file being read
# and the payload being written live in memory here as they do in production.
readonly TMP_FS='--tmpfs /tmp:exec,size=250M,mode=1777'

readonly PROBE=$(cat <<'SHELL'
set -eu
readonly RUNS=10
readonly CORPUS=/tmp/corpus
readonly CORPUS_KB=8192

# Real source text, so the compression ratio is one a kata could actually see.
# Zeroes would compress to nothing and flatter gzip; random bytes would not
# compress at all and flatter cat.
#
# The doubling is bounded, and an empty seed is a hard error: an image that
# keeps its python somewhere this find does not reach would otherwise leave the
# loop doubling nothing forever.
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

# Each file takes a different slice of the corpus. Identical files would sit
# inside gzip's 32KB window and dedupe against each other, which would report a
# compression ratio no real sandbox achieves. dd seeks to its slice, where a
# tail|head pair would re-read the whole corpus once per file.
build_sandbox()
{
  local -r count="${1}" size_kb="${2}"
  local i
  rm -rf /tmp/sandbox
  mkdir -p /tmp/sandbox
  for (( i = 0; i < count; i++ )); do
    dd if="${CORPUS}" of="/tmp/sandbox/file_${i}.py" \
       bs=1024 skip=$(( i * (size_kb + 7) % (CORPUS_KB - size_kb) )) count="${size_kb}" \
       status=none
  done
}

time_emit()
{
  local -r name="${1}" count="${2}" size_kb="${3}"
  build_sandbox "${count}" "${size_kb}"
  tar -cf /tmp/out.tar -C /tmp sandbox

  local i
  local -r t0=${EPOCHREALTIME/./}
  for (( i = 0; i < RUNS; i++ )); do cat     < /tmp/out.tar > /dev/null; done
  local -r t1=${EPOCHREALTIME/./}
  for (( i = 0; i < RUNS; i++ )); do gzip    < /tmp/out.tar > /dev/null; done
  local -r t2=${EPOCHREALTIME/./}
  for (( i = 0; i < RUNS; i++ )); do gzip -1 < /tmp/out.tar > /dev/null; done
  local -r t3=${EPOCHREALTIME/./}

  local -r cat_us=$(( (t1 - t0) / RUNS ))
  local -r gzip_us=$(( (t2 - t1) / RUNS ))
  local -r gzip1_us=$(( (t3 - t2) / RUNS ))
  local -r tar_bytes=$(stat -c %s /tmp/out.tar)
  local -r gz_bytes=$(gzip < /tmp/out.tar | wc -c)
  local -r gz1_bytes=$(gzip -1 < /tmp/out.tar | wc -c)

  printf '%-9s %4s x %4sK %9s %9s %9s %8s %8s %8s\n' \
    "${name}" "${count}" "${size_kb}" \
    "${tar_bytes}" "${gz_bytes}" "${gz1_bytes}" \
    "${cat_us}" "${gzip_us}" "${gzip1_us}"
}

build_corpus
printf '%-9s %12s %9s %9s %9s %8s %8s %8s\n' \
  profile files 'tar bytes' 'gz bytes' 'gz1 bytes' 'cat us' 'gzip us' 'gzip1 us'
time_emit typical  12   2
time_emit medium   40  10
time_emit large    16  50
time_emit ceiling  50  50
SHELL
)

probe_environment
echo "image: ${IMAGE}"
probe_preflight docker run --rm ${TMP_FS} --entrypoint='' "${IMAGE}" bash -c 'true'
docker run --rm ${TMP_FS} --entrypoint='' "${IMAGE}" bash -c "${PROBE}"
