#!/usr/bin/env bash
set -Eeu -o pipefail
# Measures what an idle pooled container costs, so a pool cap can be chosen.
#
# A pool holds warm containers per image, and a node runs many images at once,
# so the total is the per-image target multiplied by the number of hot images.
# That total is only affordable if an idle container is cheap. An idle one has
# only ever run sleep: its tmpfs mounts are empty, and --memory=2g is a cap
# rather than a reservation, so the expectation is single-digit MB. This probe
# is what turns that expectation into a number.
#
# Three things are measured as the idle count rises, because they bind at
# different points:
#   o) memory the whole machine has lost, which includes the daemon's own
#      bookkeeping and not merely the containers' processes
#   o) what docker itself reports for one container
#   o) how long a press takes, since a daemon tracking hundreds of containers
#      may answer more slowly even when memory is fine
#
# Memory is read from inside a container because containers share the kernel
# whose free memory matters, which on Docker Desktop is the VM's and not the
# Mac's.

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${MY_DIR}/probe_lib.sh"

probe_help_check "${1:-}" \
"Usage: docs/profiling/measure_idle_warm_container_cost.sh [-h] [IMAGE]

Starts idle containers in batches and reports memory lost, per-container usage
and press latency at each batch size. Removes every container it started.

Options:
  -h    Show this help

Example:
  docs/profiling/measure_idle_warm_container_cost.sh ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a"

readonly IMAGE="${1:-ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a}"
readonly NAME_PREFIX="probe_idle_$$"
readonly LEVELS='10 25 50'
readonly PRESS_RUNS=5

readonly UID_SANDBOX=41966
readonly GID_SANDBOX=51966

# The flag set from docker_run_cyber_dojo_sh_command in runner.rb, so the idle
# containers carry the same tmpfs mounts and limits a real one would.
readonly RUNNER_FLAGS="--init --interactive --user=${UID_SANDBOX}:${GID_SANDBOX} \
--tmpfs /sandbox:exec,size=250M,uid=${UID_SANDBOX},gid=${GID_SANDBOX} \
--tmpfs /tmp:exec,size=250M,mode=1777 \
--ulimit core=0 --ulimit fsize=268435456 --ulimit locks=1024 \
--ulimit nofile=1024 --ulimit nproc=1024 --ulimit stack=16777216 \
--ulimit data=4294967296 \
--memory=2g --net=none --pids-limit=128 --security-opt=no-new-privileges"

# Removes every container this probe started, however it exits, so a failed
# run does not leave the machine holding hundreds of them.
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

# Prints the kernel's available memory in KB, read from inside a container so
# it is the kernel the containers actually share.
available_kb()
{
  docker run --rm --entrypoint='' "${IMAGE}" \
    awk '/MemAvailable/ { print $2 }' /proc/meminfo
}

# Prints the mean milliseconds of a press that creates its own container, which
# is what a pool miss costs and what a busy daemon would slow down.
press_ms()
{
  local i
  local -r t0=${EPOCHREALTIME/./}
  for (( i = 0; i < PRESS_RUNS; i++ )); do
    docker run --rm --entrypoint='' "${IMAGE}" true > /dev/null 2>&1
  done
  local -r t1=${EPOCHREALTIME/./}
  echo $(( (t1 - t0) / PRESS_RUNS / 1000 ))
}

# Starts count idle containers, numbered from the current total.
start_idle()
{
  local -r from="${1}" to="${2}"
  local i
  for (( i = from; i < to; i++ )); do
    # shellcheck disable=SC2086
    docker run --detach ${RUNNER_FLAGS} --name "${NAME_PREFIX}_${i}" \
      --entrypoint='' "${IMAGE}" sleep 600 > /dev/null
  done
}

probe_environment
echo "image: ${IMAGE}"
echo

readonly BASE_KB="$(available_kb)"
readonly BASE_PRESS="$(press_ms)"

printf '%8s %14s %14s %12s %10s\n' idle 'avail KB' 'lost KB' 'KB each' 'press ms'
printf '%8s %14s %14s %12s %10s\n' 0 "${BASE_KB}" 0 0 "${BASE_PRESS}"

started=0
for level in ${LEVELS}; do
  start_idle "${started}" "${level}"
  started="${level}"

  avail_kb="$(available_kb)"
  lost_kb=$(( BASE_KB - avail_kb ))
  printf '%8s %14s %14s %12s %10s\n' \
    "${started}" "${avail_kb}" "${lost_kb}" "$(( lost_kb / started ))" "$(press_ms)"
done

echo
echo 'docker stats for one idle container:'
docker stats --no-stream --format '{{.Name}} {{.MemUsage}} {{.PIDs}}' "${NAME_PREFIX}_0"
