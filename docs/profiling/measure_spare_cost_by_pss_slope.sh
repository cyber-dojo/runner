#!/usr/bin/env bash
set -Eeu -o pipefail
# What one idle spare costs the machine, measured as a slope rather than a level.
#
# measure_idle_warm_container_cost.sh answers this from MemAvailable, which moves
# with whatever else the host is doing: the same probe on the same machine said
# about 12MB each with 7.4GB available and about 5.2MB each with 5.7GB. A factor
# of 2.3 is the difference between docs/pre-started-container-pool.md's four-LTF
# row needing half a gigabyte and needing a quarter of one.
#
# Two changes. Memory is read as the sum of every process's Pss rather than as
# what the machine says is free, so nothing but processes is counted. And it is
# read at several idle counts, so what is reported is the increment per
# container: a slope cancels the fixed overhead and much of the drift a single
# before-and-after cannot.
#
# Pss rather than Rss because the per-container shims share their libraries, and
# Rss counts a shared page once for every process mapping it. Pss divides each
# page by how many map it, so summing Pss across all processes counts every
# resident page exactly once.
#
# The processes live in the VM rather than in any container, so the reader runs
# with --pid=host: a shim is the daemon's child on the host, and the whole point
# is to count it. Every process is summed rather than the shims alone, because
# dockerd and containerd grow with what they track and that growth is as real as
# the shims'.
#
# What it found, on aarch64 under Docker Desktop, with python_pytest:
#
#     idle   total pss MB    above base MB    per idle MB
#        0           1757                0              -
#        8           1808               51            6.4
#       16           1840               83            5.2
#       32           1924              167            5.2
#
# About 5.2MB, and the same at sixteen and at thirty-two, so the slope is stable
# where the level was not. The 6.4MB at eight is the first batch's fixed part
# divided by fewer containers rather than a different cost per container.
#
# So 5.2MB is the figure to size a cap from, and the 12MB it replaces stands as
# an upper bound rather than a measurement.
#
# What it cannot answer. Pss is process memory, so kernel memory that a container
# costs, slab and page tables, is not in it: the truth is above 5.2MB and below
# the 12MB MemAvailable suggested. And a Docker Desktop VM is not the aws-prod
# node, which is the same limitation the figure it replaces has.

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${MY_DIR}/probe_lib.sh"

probe_help_check "${1:-}" \
"Usage: docs/profiling/measure_spare_cost_by_pss_slope.sh [-h] [IMAGE]

Starts idle containers in batches, sums every process's Pss at each batch size,
and reports the increment per container. Removes every container it started.

Options:
  -h    Show this help

Example:
  docs/profiling/measure_spare_cost_by_pss_slope.sh ghcr.io/cyber-dojo-languages/python_pytest:4833cf7"

readonly IMAGE="${1:-ghcr.io/cyber-dojo-languages/python_pytest:4833cf7}"
readonly NAME_PREFIX="probe_pss_$$"
readonly LEVELS='8 16 32'

# A spare's own command, as CyberDojoShContainerConfig gives it: a sleep long
# enough to outlast the probe, and nothing else.
readonly SLEEP_SECONDS=600

# Sums Pss across every process the VM is running. smaps_rollup is one line per
# field per process, which is far cheaper to read than smaps. A process that
# exits while this runs takes its file with it, so a missing one is skipped
# rather than failing the sum.
#
# --privileged, because reading another process's smaps needs ptrace access to
# it and SYS_PTRACE alone was not enough here. grep selects the lines before awk
# adds them, rather than awk reading the files itself: given the files directly,
# busybox awk answered nothing and exited 1.
sum_pss_kb()
{
  docker run --rm --pid=host --privileged --entrypoint='' alpine:3.24 \
    sh -c 'grep -h "^Pss:" /proc/[0-9]*/smaps_rollup 2>/dev/null | awk "{ t += \$2 } END { print t+0 }"'
}

# Each level adds to the last rather than starting again, so the names count up
# across the whole run: naming them per level collides the moment a second level
# starts at zero.
next_spare=0

start_spares()
{
  local -r count="${1}"
  local i
  for (( i = 0; i < count; i++ )); do
    docker run --detach --name "${NAME_PREFIX}_${next_spare}" \
      --entrypoint='' "${IMAGE}" sleep "${SLEEP_SECONDS}" > /dev/null
    next_spare=$(( next_spare + 1 ))
  done
}

remove_spares()
{
  local name
  for name in $(docker ps --all --filter "name=${NAME_PREFIX}" --format '{{.Names}}'); do
    docker rm --force "${name}" > /dev/null
  done
}

trap remove_spares EXIT

probe_environment
echo "image: ${IMAGE}"
echo

# The zero level is the baseline every slope is taken against, and it is read
# after the image is pulled, so no level pays for a pull the others do not.
docker pull --quiet "${IMAGE}" > /dev/null
readonly BASE_KB="$(sum_pss_kb)"
printf '%8s %14s %16s %14s\n' 'idle' 'total pss MB' 'above base MB' 'per idle MB'
printf '%8s %14s %16s %14s\n' 0 "$(( BASE_KB / 1024 ))" 0 '-'

started=0
for level in ${LEVELS}; do
  start_spares "$(( level - started ))"
  started="${level}"
  # A shim settles within a second of its container starting, and reading before
  # it has costs the level a figure that is still rising.
  sleep 2
  now_kb="$(sum_pss_kb)"
  above_kb=$(( now_kb - BASE_KB ))
  printf '%8s %14s %16s %14s\n' \
    "${level}" \
    "$(( now_kb / 1024 ))" \
    "$(( above_kb / 1024 ))" \
    "$(( above_kb / level / 1024 )).$(( (above_kb * 10 / level / 1024) % 10 ))"
done
