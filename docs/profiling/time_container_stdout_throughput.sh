#!/usr/bin/env bash
set -Eeu -o pipefail
# Measures what the runner saves by receiving fewer bytes.
#
# The gzip in send_tgz() buys nothing but a smaller payload on the path
# container -> daemon -> docker CLI -> runner. That saving is only worth having
# if those bytes are expensive, so this probe prices them: it emits payloads of
# several sizes from a container's stdout and reads them on the host, exactly as
# capture3_with_timeout.rb does.
#
# Subtracting the empty-payload run from each row leaves the transfer cost
# alone, with container startup, which dominates it, removed.

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${MY_DIR}/probe_lib.sh"

probe_help_check "${1:-}" \
"Usage: docs/profiling/time_container_stdout_throughput.sh [-h] [IMAGE]

Times docker run reading payloads of several sizes from a container's stdout,
and prints the transfer cost with container startup subtracted out.

Options:
  -h    Show this help

Example:
  docs/profiling/time_container_stdout_throughput.sh ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd"

readonly IMAGE="${1:-ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd}"
readonly RUNS=5

# Emits KB kilobytes on stdout from a tmpfs file, so the measurement is the
# transfer and not the reading of a disk.
emit()
{
  local -r kb="${1}"
  docker run --rm --tmpfs /tmp:exec,size=250M,mode=1777 --entrypoint='' "${IMAGE}" \
    bash -c "dd if=/dev/zero of=/tmp/payload bs=1024 count=${kb} status=none; cat /tmp/payload"
}

# Prints the mean wall-clock of RUNS emits of KB kilobytes, with the caller's
# baseline subtracted.
time_emit()
{
  local -r kb="${1}" baseline_us="${2}"
  local i
  local -r t0=${EPOCHREALTIME/./}
  for (( i = 0; i < RUNS; i++ )); do emit "${kb}" > /dev/null; done
  local -r t1=${EPOCHREALTIME/./}
  local -r mean_us=$(( (t1 - t0) / RUNS ))
  printf '%10s KB %12s us %12s us\n' "${kb}" "${mean_us}" "$(( mean_us - baseline_us ))"
  MEAN_US=${mean_us}
}

probe_environment
echo "image: ${IMAGE}"
probe_preflight docker run --rm --entrypoint='' "${IMAGE}" bash -c 'true'

printf '%13s %15s %15s\n' payload 'docker run' 'minus startup'
MEAN_US=0
time_emit 0 0
readonly BASELINE_US=${MEAN_US}
time_emit 8 "${BASELINE_US}"     # a typical kata, gzipped
time_emit 40 "${BASELINE_US}"    # a typical kata, not gzipped
time_emit 640 "${BASELINE_US}"   # the 50-file ceiling, gzipped
time_emit 2560 "${BASELINE_US}"  # the 50-file ceiling, not gzipped
