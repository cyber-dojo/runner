#!/usr/bin/env bash
set -Eeu -o pipefail
# Measures what --rm costs the learner.
#
# runner.rb runs the container with --rm, and capture3_with_timeout.rb waits on
# waiter.value, which is the docker CLI process exiting. With --rm the CLI does
# not exit until the container has been removed, so container teardown sits on
# the path between the tests finishing and the traffic-light appearing, even
# though the payload was complete when the container's stdout closed.
#
# Dropping --rm and removing the container from a thread would take that off
# the path. This probe prices it: the same container run both ways, with the
# deferred [docker rm] timed separately so the work being moved is visible
# rather than merely hidden.
#
# The two variants are interleaved because a laptop's docker daemon drifts, and
# running ten of one and then ten of the other would attribute that drift to
# the change.

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${MY_DIR}/probe_lib.sh"

probe_help_check "${1:-}" \
"Usage: docs/profiling/time_container_removal_inline_vs_deferred.sh [-h] [IMAGE]

Times [docker run --rm] against [docker run] followed by a separate
[docker rm], and reports both the run and the deferred removal.

Options:
  -h    Show this help

Example:
  docs/profiling/time_container_removal_inline_vs_deferred.sh ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd"

readonly IMAGE="${1:-ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd}"
readonly RUNS=10

# Mirrors the flags runner.rb uses, since --init is there specifically because
# it makes container removal faster, and the tmpfs mounts are part of what has
# to be torn down.
readonly FLAGS="--init --tmpfs /sandbox:exec,size=250M --tmpfs /tmp:exec,size=250M,mode=1777"

# A payload the size of a typical kata's, so the run being timed is doing the
# same kind of work the real one does rather than exiting instantly.
readonly PAYLOAD_KB=64
readonly EMIT="dd if=/dev/zero bs=1024 count=${PAYLOAD_KB} status=none | gzip -1"

probe_environment
echo "image: ${IMAGE}"
probe_preflight docker run --rm --entrypoint='' "${IMAGE}" bash -c 'true'

inline_total=0
deferred_run_total=0
deferred_rm_total=0

for (( i = 0; i < RUNS; i++ )); do
  name="probe_removal_${i}_$$"

  t0=${EPOCHREALTIME/./}
  # shellcheck disable=SC2086
  docker run --rm ${FLAGS} --name "${name}_inline" --entrypoint='' \
    "${IMAGE}" bash -c "${EMIT}" > /dev/null
  t1=${EPOCHREALTIME/./}
  inline_total=$(( inline_total + t1 - t0 ))

  t2=${EPOCHREALTIME/./}
  # shellcheck disable=SC2086
  docker run ${FLAGS} --name "${name}_deferred" --entrypoint='' \
    "${IMAGE}" bash -c "${EMIT}" > /dev/null
  t3=${EPOCHREALTIME/./}
  deferred_run_total=$(( deferred_run_total + t3 - t2 ))

  # What the thread would do, after the learner already has their result.
  t4=${EPOCHREALTIME/./}
  docker rm "${name}_deferred" > /dev/null
  t5=${EPOCHREALTIME/./}
  deferred_rm_total=$(( deferred_rm_total + t5 - t4 ))
done

readonly INLINE_US=$(( inline_total / RUNS ))
readonly DEFERRED_US=$(( deferred_run_total / RUNS ))
readonly RM_US=$(( deferred_rm_total / RUNS ))

printf '%-34s %10s us\n' 'docker run --rm' "${INLINE_US}"
printf '%-34s %10s us\n' 'docker run, removal deferred' "${DEFERRED_US}"
printf '%-34s %10s us\n' 'off the path: the later docker rm' "${RM_US}"
printf '%-34s %10s us\n' 'saved per traffic-light' "$(( INLINE_US - DEFERRED_US ))"
