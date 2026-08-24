#!/usr/bin/env bash
# Price each group of flags the runner passes to `docker run`, by adding them one
# group at a time.
#
# It found that everything except --net=none is free within noise, and that
# --net=none saves about 36ms against default bridge networking and is already
# passed. So there is no flag-level win left, and in particular the two 250MB
# tmpfs mounts cost nothing to set up and are not worth shrinking. See
# cyber-dojo/faster-traffic-light.md, finding 6.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/probe_lib.sh"

probe_help_check "${1:-}" "Usage: time_docker_run_flags.sh [image]

Defaults to the perl-testsimple language image. Best run on the host, where
there is no emulated-CLI cost to swamp the differences between flag groups:

  bash time_docker_run_flags.sh"

readonly IMG="${1:-ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a}"
readonly RUNS=10

readonly SANDBOX_UID=41966
readonly SANDBOX_GID=51966

readonly TMPFS="--tmpfs /sandbox:exec,size=250M,uid=${SANDBOX_UID},gid=${SANDBOX_GID} \
--tmpfs /tmp:exec,size=250M,mode=1777"
readonly ULIMITS="--ulimit core=0 --ulimit fsize=268435456 --ulimit locks=1024 \
--ulimit nofile=1024 --ulimit nproc=1024 --ulimit stack=16777216 \
--ulimit data=4294967296"
readonly HARDEN="--memory=2g --pids-limit=128 --security-opt=no-new-privileges"

# Run the image with whatever flags are passed, so each call below differs only
# by the group being added.
run_with()
{
  # shellcheck disable=SC2086
  docker run --rm --entrypoint= $* "${IMG}" true
}

probe_environment
echo "image: ${IMG}"
echo

probe_preflight run_with
probe_preflight run_with --net=none

probe_timeit_ms 'baseline (default bridge net)'   "${RUNS}" run_with
probe_timeit_ms 'plus --net=none'                 "${RUNS}" run_with --net=none
probe_timeit_ms 'plus --init'                     "${RUNS}" run_with --net=none --init
probe_timeit_ms 'plus tmpfs x2'                   "${RUNS}" run_with --net=none --init ${TMPFS}
probe_timeit_ms 'plus ulimits x7'                 "${RUNS}" run_with --net=none --init ${TMPFS} ${ULIMITS}
probe_timeit_ms 'plus memory/pids/no-new-privs'   "${RUNS}" run_with --net=none --init ${TMPFS} ${ULIMITS} ${HARDEN}
probe_timeit_ms 'plus --user (full runner set)'   "${RUNS}" run_with --net=none --init ${TMPFS} ${ULIMITS} ${HARDEN} --user=${SANDBOX_UID}:${SANDBOX_GID}
