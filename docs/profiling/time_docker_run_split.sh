#!/usr/bin/env bash
# Split `docker run` into its create, start and remove phases.
#
# The question it answers: could the runner keep a pool of pre-created but
# never-started containers, paying create ahead of the user's press and only
# start on the critical path? That would preserve the guarantee that every press
# gets a container nothing else has touched.
#
# The answer is mostly no. It found create at about 16ms of daemon work against
# start at about 48ms, so pre-creating recovers only the smaller half. It also
# found removal at about 15ms, which the runner pays inside the timed span
# because it passes --rm, and which a background reap would recover. See
# cyber-dojo/faster-traffic-light.md, finding 6.
#
# Each phase pays one docker CLI invocation, about 15ms, so subtract that from
# each figure to get the daemon's own work.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/probe_lib.sh"

probe_help_check "${1:-}" "Usage: time_docker_run_split.sh [image]

Defaults to the perl-testsimple language image, whose body is only 12ms so it
perturbs the measurement least. Run on the host:

  bash time_docker_run_split.sh"

readonly IMG="${1:-ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a}"
readonly RUNS=10

readonly SANDBOX_UID=41966
readonly SANDBOX_GID=51966

# The flag set from docker_run_cyber_dojo_sh_command in source/server/runner.rb,
# minus --rm, because this probe removes the container as a separate timed step.
readonly RUNNER_FLAGS="--init --interactive --user=${SANDBOX_UID}:${SANDBOX_GID} \
--tmpfs /sandbox:exec,size=250M,uid=${SANDBOX_UID},gid=${SANDBOX_GID} \
--tmpfs /tmp:exec,size=250M,mode=1777 \
--ulimit core=0 --ulimit fsize=268435456 --ulimit locks=1024 \
--ulimit nofile=1024 --ulimit nproc=1024 --ulimit stack=16777216 \
--ulimit data=4294967296 \
--memory=2g --net=none --pids-limit=128 --security-opt=no-new-privileges"

probe_environment
echo "image: ${IMG}"
echo

total_create=0
total_start=0
total_rm=0

for (( i = 0; i < RUNS; i++ )); do
  t0=${EPOCHREALTIME/./}
  # shellcheck disable=SC2086
  cid="$(docker create --entrypoint= ${RUNNER_FLAGS} "${IMG}" true)"
  t1=${EPOCHREALTIME/./}
  docker start --attach "${cid}" > /dev/null 2>&1
  t2=${EPOCHREALTIME/./}
  docker rm --force "${cid}" > /dev/null 2>&1
  t3=${EPOCHREALTIME/./}

  total_create=$(( total_create + t1 - t0 ))
  total_start=$(( total_start + t2 - t1 ))
  total_rm=$(( total_rm + t3 - t2 ))
done

printf '%-34s %6s ms\n' 'docker create'         "$(( total_create / RUNS / 1000 ))"
printf '%-34s %6s ms\n' 'docker start --attach' "$(( total_start / RUNS / 1000 ))"
printf '%-34s %6s ms\n' 'docker rm --force'     "$(( total_rm / RUNS / 1000 ))"
printf '%-34s %6s ms\n' 'sum of the three'      "$(( (total_create + total_start + total_rm) / RUNS / 1000 ))"
