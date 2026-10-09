#!/usr/bin/env bash
set -Eeu -o pipefail
# Measures what a spare is worth and what a pool costs, as two numbers.
#
# A test-run that claims a spare execs into a container that already exists.
# A test-run that misses creates and starts one first. The difference between
# those two is the whole of what the pool buys, and it is measured here as
#
#   hit  = exec + stop
#   miss = create + start + exec + stop
#
# The pool is not free, though. Idle containers are containers the daemon
# tracks, and measure_idle_warm_container_cost.sh showed a create-and-remove
# slowing from 183ms to 225ms as fifty of them accumulated. So both numbers are
# measured again with idle containers standing in the background, which is what
# says whether a large pool taxes the misses more than its hits save.
#
# Finally both are measured with several running at once, because a node runs
# one puma worker per processor and they all share one daemon. A number taken
# one call at a time says nothing about a daemon serving ten workers.

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${MY_DIR}/probe_lib.sh"

probe_help_check "${1:-}" \
"Usage: docs/profiling/time_hit_vs_miss_under_load.sh [-h] [IMAGE]

Reports the mean milliseconds of a hit and of a miss, at several pool sizes,
serially and with eight running at once. Removes every container it started.

Options:
  -h    Show this help

Example:
  docs/profiling/time_hit_vs_miss_under_load.sh ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd"

readonly IMAGE="${1:-ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd}"
readonly NAME_PREFIX="probe_hitmiss_$$"
readonly IDLE_LEVELS='0 8 32'
readonly SAMPLES=10
readonly CONCURRENCY=8

readonly UID_SANDBOX=41966
readonly GID_SANDBOX=51966

# The flags runner.rb creates a container with, so the containers timed here
# carry the same tmpfs mounts and limits a real one would.
readonly RUNNER_FLAGS="--init --interactive --user=${UID_SANDBOX}:${GID_SANDBOX} \
--tmpfs /sandbox:exec,size=250M,uid=${UID_SANDBOX},gid=${GID_SANDBOX} \
--tmpfs /tmp:exec,size=250M,mode=1777 \
--ulimit core=0 --ulimit fsize=268435456 --ulimit locks=1024 \
--ulimit nofile=1024 --ulimit nproc=1024 --ulimit stack=16777216 \
--ulimit data=4294967296 \
--memory=2g --net=none --pids-limit=128 --security-opt=no-new-privileges"

# Removes every container this probe started, however it exits.
cleanup()
{
  local ids
  ids="$(docker ps --all --quiet --filter "name=${NAME_PREFIX}")"
  if [ -n "${ids}" ]; then
    # shellcheck disable=SC2086
    docker rm --force ${ids} > /dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# Starts one container and answers its name. Its Cmd is a sleep, as a spare's
# is, so it is there to be exec'd into.
start_container()
{
  local -r name="${1}"
  # shellcheck disable=SC2086
  docker run --detach ${RUNNER_FLAGS} --name "${name}" \
    --entrypoint='' "${IMAGE}" sleep 600 > /dev/null
  echo "${name}"
}

# What a test-run costs when it claims a spare: the exec, and the stop that
# disposes of the container afterwards. The container is made beforehand,
# because that is what the pool did.
one_hit()
{
  local -r name="${1}"
  docker exec "${name}" true > /dev/null 2>&1
  docker stop --timeout 1 "${name}" > /dev/null 2>&1
}

# What a test-run costs when it misses: the same, with the create and the start
# it has to do first.
one_miss()
{
  local -r name="${1}"
  start_container "${name}" > /dev/null
  one_hit "${name}"
}

# Runs one_hit or one_miss SAMPLES times, one after another, and prints the
# mean in milliseconds. A hit needs its container made first, and that making
# is not timed.
time_serial()
{
  local -r kind="${1}" tag="${2}"
  local i
  if [ "${kind}" = 'hit' ]; then
    for (( i = 0; i < SAMPLES; i++ )); do
      start_container "${NAME_PREFIX}_${tag}_${i}" > /dev/null
    done
  fi
  local -r t0=${EPOCHREALTIME/./}
  for (( i = 0; i < SAMPLES; i++ )); do
    "one_${kind}" "${NAME_PREFIX}_${tag}_${i}"
  done
  local -r t1=${EPOCHREALTIME/./}
  echo $(( (t1 - t0) / SAMPLES / 1000 ))
}

# The same, with CONCURRENCY of them in flight at once, which is what a daemon
# serving several puma workers sees. The mean is wall-clock over the batch
# divided by the batch size, so it is throughput rather than latency.
time_concurrent()
{
  local -r kind="${1}" tag="${2}"
  local i
  if [ "${kind}" = 'hit' ]; then
    for (( i = 0; i < CONCURRENCY; i++ )); do
      start_container "${NAME_PREFIX}_${tag}_c${i}" > /dev/null
    done
  fi
  local -r t0=${EPOCHREALTIME/./}
  for (( i = 0; i < CONCURRENCY; i++ )); do
    "one_${kind}" "${NAME_PREFIX}_${tag}_c${i}" &
  done
  wait
  local -r t1=${EPOCHREALTIME/./}
  echo $(( (t1 - t0) / CONCURRENCY / 1000 ))
}

# Brings the number of idle background containers up to a level, and leaves
# them running while the timings are taken.
idle_started=0
set_idle()
{
  local -r to="${1}"
  local i
  for (( i = idle_started; i < to; i++ )); do
    start_container "${NAME_PREFIX}_idle_${i}" > /dev/null
  done
  idle_started="${to}"
}

probe_environment
echo "image: ${IMAGE}"
echo "samples: ${SAMPLES}, concurrency: ${CONCURRENCY}"
echo

printf '%6s %10s %10s %14s %14s\n' idle 'hit ms' 'miss ms' 'hit x8 ms' 'miss x8 ms'
for level in ${IDLE_LEVELS}; do
  set_idle "${level}"
  hit="$(time_serial hit "s${level}")"
  miss="$(time_serial miss "m${level}")"
  hit_c="$(time_concurrent hit "cs${level}")"
  miss_c="$(time_concurrent miss "cm${level}")"
  printf '%6s %10s %10s %14s %14s\n' "${level}" "${hit}" "${miss}" "${hit_c}" "${miss_c}"
done
