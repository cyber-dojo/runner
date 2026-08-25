#!/usr/bin/env bash
set -Eeu -o pipefail
# Measures what send_tgz()'s intermediate tar file costs.
#
# send_tgz() in home_files.rb builds ${TAR_FILE} on tmpfs with two [tar -rf]
# passes, one for cyber-dojo.sh's three streams and one for the sandbox files
# from find, and then reads the whole thing back through gzip. The bytes
# therefore cross tmpfs three times: written, appended to, read.
#
# tar can take path operands and -T on the same command line, so the same
# archive can be produced by a single tar writing straight into gzip, with no
# intermediate file at all. This probe times both, at the payload sizes a kata
# actually returns, and checks the two produce the same archive.
#
# Whether the streamed form is available everywhere is a separate question:
# busybox tar is not GNU tar, and a probe that only runs here proves nothing
# about the other images. This one reports whether the streamed form worked, so
# a host-side loop over every image can answer that too.

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${MY_DIR}/probe_lib.sh"

probe_help_check "${1:-}" \
"Usage: docs/profiling/time_streamed_tar_vs_tar_file.sh [-h] [IMAGE]

Times send_tgz()'s [tar -rf] to a file then gzip, against a single tar piped
straight into gzip, for several sandbox payload sizes.

Options:
  -h    Show this help

Example:
  docs/profiling/time_streamed_tar_vs_tar_file.sh ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd"

readonly IMAGE="${1:-ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd}"
readonly TMP_FS='--tmpfs /tmp:exec,size=250M,mode=1777'

readonly PROBE=$(cat <<'SHELL'
set -eu
readonly RUNS=10
readonly CORPUS=/tmp/corpus
readonly CORPUS_KB=8192
readonly SANDBOX=/tmp/sandbox

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

build_sandbox()
{
  local -r count="${1}" size_kb="${2}"
  local i
  rm -rf "${SANDBOX}"
  mkdir -p "${SANDBOX}"
  for (( i = 0; i < count; i++ )); do
    dd if="${CORPUS}" of="${SANDBOX}/file_${i}.py" \
       bs=1024 skip=$(( i * (size_kb + 7) % (CORPUS_KB - size_kb) )) count="${size_kb}" \
       status=none
  done
  # cyber-dojo.sh's three streams, as send_tgz() finds them.
  printf 'All tests passed\n' > /tmp/stdout
  printf '' > /tmp/stderr
  printf '0' > /tmp/status
}

print0_filenames()
{
  find "${SANDBOX}" -type f -print0
}

# What send_tgz() does now: append to a file on tmpfs, then read it back.
emit_via_file()
{
  local -r tar_file=/tmp/emit.tar
  rm -f "${tar_file}"
  tar -rf "${tar_file}" /tmp/stdout /tmp/stderr /tmp/status
  print0_filenames | tar -rf "${tar_file}" --verbatim-files-from --null -T -
  gzip -1 < "${tar_file}"
}

# The same archive from one tar, straight into gzip, with no file in between.
emit_streamed()
{
  print0_filenames \
    | tar -cf - --verbatim-files-from --null \
        /tmp/stdout /tmp/stderr /tmp/status -T - \
    | gzip -1
}

time_emit()
{
  local -r name="${1}" count="${2}" size_kb="${3}"
  build_sandbox "${count}" "${size_kb}"

  local streamed=ok
  if ! emit_streamed > /tmp/streamed.tgz 2>/dev/null; then
    streamed=FAILED
  fi
  emit_via_file > /tmp/via_file.tgz

  # Same members, in the same order, is what makes the timings comparable.
  local same=same
  if ! cmp -s /tmp/streamed.tgz /tmp/via_file.tgz; then
    if [ "$(gzip -d -c /tmp/streamed.tgz | tar -tf - | sort | md5sum)" \
       = "$(gzip -d -c /tmp/via_file.tgz | tar -tf - | sort | md5sum)" ]; then
      same='same members'
    else
      same=DIFFER
    fi
  fi

  local i
  local -r t0=${EPOCHREALTIME/./}
  for (( i = 0; i < RUNS; i++ )); do emit_via_file > /dev/null; done
  local -r t1=${EPOCHREALTIME/./}
  for (( i = 0; i < RUNS; i++ )); do emit_streamed > /dev/null; done
  local -r t2=${EPOCHREALTIME/./}

  local -r file_us=$(( (t1 - t0) / RUNS ))
  local -r streamed_us=$(( (t2 - t1) / RUNS ))

  printf '%-9s %4s x %4sK %10s %10s %10s  %-8s %s\n' \
    "${name}" "${count}" "${size_kb}" \
    "${file_us}" "${streamed_us}" "$(( file_us - streamed_us ))" \
    "${streamed}" "${same}"
}

build_corpus
printf '%-9s %12s %10s %10s %10s  %-8s %s\n' \
  profile files 'via file' 'streamed' 'saving' streamed archive
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
