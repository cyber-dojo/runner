#!/usr/bin/env bash
set -Eeu -o pipefail
# Checks what a pooled spare's sleep ending does to a test-run already using it.
#
# A spare's Cmd is a sleep, and AutoRemove disposes of the container when that
# sleep ends, which is what bounds a leak without any bookkeeping. A claim
# landing near the end of a sleep is therefore a race, and this probe is what
# says whether losing that race is a clean miss or a broken run.
#
# Two checks, being the two sides of the boundary:
#
#   under a run    An exec wanting longer than the sleep it runs inside. The
#                  container's PID 1 is that sleep, so the question is whether
#                  an exec outlives it. It does not: the output stops where the
#                  sleep ends and the exec exits 137, which is SIGKILL. For a
#                  kata that means being killed part way through, and the
#                  runner then reads a truncated gzip and answers the learner
#                  faulty for a kata that was fine.
#
#   after it went  An exec create naming a container that is no longer usable,
#                  which is what a claim landing a moment later would send. Two
#                  answers, depending on how far the container has got: 404 No
#                  such container once it has been removed, and 409 is not
#                  running while it has exited but is still there. Neither is
#                  the 404 which means an image has left the node, and reading
#                  either as one would discard a present image. See
#                  test/server/run_missing_container_keeps_pulled_test.rb
#
# Which together are why step 4 of docs/pre-started-container-pool.md declines
# a spare with too little sleep left rather than racing it.

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${MY_DIR}/probe_lib.sh"

probe_help_check "${1:-}" \
"Usage: docs/profiling/check_spare_sleep_ending_under_a_run.sh [-h] [IMAGE]

Starts a container that sleeps briefly, execs a longer-running job into it, and
reports where the output stopped and how the exec exited. Then asks the daemon
for an exec in a container that does not exist. Removes what it started.

Options:
  -h    Show this help

Example:
  docs/profiling/check_spare_sleep_ending_under_a_run.sh alpine:3.24"

readonly IMAGE="${1:-alpine:3.24}"
readonly NAME="probe_spare_expiry_$$"
readonly SLEEP_SECONDS=5
readonly EXEC_SECONDS=10
readonly SOCKET_PATH=/var/run/docker.sock

# --rm disposes of the container when its sleep ends, as AutoRemove does for a
# spare, so this only has to catch the case where the probe died first.
cleanup()
{
  docker rm --force "${NAME}" "${NAME}_exited" > /dev/null 2>&1 || true
}
trap cleanup EXIT

# Asks the daemon for an exec in the named container and prints what it said.
exec_create()
{
  curl --silent --unix-socket "${SOCKET_PATH}" \
    --write-out 'HTTP %{http_code}\n' \
    --header 'Content-Type: application/json' \
    --data '{"Cmd":["true"]}' \
    --request POST "http://docker/containers/${1}/exec"
}

probe_environment
echo "image: ${IMAGE}"
echo "container sleeps ${SLEEP_SECONDS}s, exec asks for ${EXEC_SECONDS}s"
echo

# --init so that PID 1 is tini, which is what a spare has.
docker run --detach --rm --init --name "${NAME}" \
  --entrypoint='' "${IMAGE}" sleep "${SLEEP_SECONDS}" > /dev/null

# One line a second, so where the output stops says when the exec was killed.
# The failure is the finding, so set -e is lifted rather than aborting here.
set +e
docker exec "${NAME}" sh -c \
  "i=0; while [ \$i -lt ${EXEC_SECONDS} ]; do echo line\$i; i=\$((i+1)); sleep 1; done"
EXEC_STATUS=$?
set -e
readonly EXEC_STATUS

echo
echo "exec exit status: ${EXEC_STATUS}"
echo '137 is 128+9, so SIGKILL: the exec went when the container did.'
echo

# A name nothing ever had answers the same as one whose container has just been
# removed, without racing the removal to ask.
echo 'exec create naming a container that does not exist:'
exec_create "${NAME}_never_existed"
echo

# Stopped rather than removed, which is the same boundary a moment earlier.
readonly EXITED="${NAME}_exited"
docker run --detach --name "${EXITED}" --entrypoint='' "${IMAGE}" sleep 30 > /dev/null
docker stop --time 0 "${EXITED}" > /dev/null
echo "exec create naming a container that has exited but is still there:"
exec_create "${EXITED}"
docker rm --force "${EXITED}" > /dev/null 2>&1
