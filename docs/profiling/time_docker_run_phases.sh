#!/usr/bin/env bash
# Decompose the runner's fixed per-press overhead into docker CLI cost and
# daemon container-lifecycle cost.
#
# Run it twice: on the host, and inside the runner image with the docker socket
# mounted. The difference isolates the CLI, because the container lifecycle
# happens in the daemon and so is unaffected by the runner container's own
# architecture or emulation.
#
# It found the lifecycle to be about 92ms native and the CLI about 16ms, which
# is why reducing container creation matters more than replacing the CLI. See
# cyber-dojo/faster-traffic-light.md, finding 6.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/probe_lib.sh"

probe_help_check "${1:-}" "Usage: time_docker_run_phases.sh [image]

Defaults to the perl-testsimple language image, chosen because its body is only
12ms so it perturbs the measurement least.

On the host:
  bash time_docker_run_phases.sh

Inside the runner, to price its CLI as the runner actually pays for it:
  docker run --rm --entrypoint=\"\" \\
    --volume /var/run/docker.sock:/var/run/docker.sock \\
    --volume \$PWD:/probe:ro cyberdojo/runner:latest \\
    bash /probe/time_docker_run_phases.sh"

readonly IMG="${1:-ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a}"
readonly RUNS=10

readonly SANDBOX_UID=41966
readonly SANDBOX_GID=51966

# The flag set from docker_run_cyber_dojo_sh_command in source/server/runner.rb.
# Kept as a single string so it can be word-split into docker's argv.
readonly RUNNER_FLAGS="--init --interactive --rm --user=${SANDBOX_UID}:${SANDBOX_GID} \
--tmpfs /sandbox:exec,size=250M,uid=${SANDBOX_UID},gid=${SANDBOX_GID} \
--tmpfs /tmp:exec,size=250M,mode=1777 \
--ulimit core=0 --ulimit fsize=268435456 --ulimit locks=1024 \
--ulimit nofile=1024 --ulimit nproc=1024 --ulimit stack=16777216 \
--ulimit data=4294967296 \
--memory=2g --net=none --pids-limit=128 --security-opt=no-new-privileges"

probe_environment
echo "image: ${IMG}"
echo

# CLI process start plus one trivial daemon round trip, creating no container.
# Subtracting this from the figures below leaves the container lifecycle.
cli_only()
{
  docker version --format '{{.Server.Version}}'
}

# The whole lifecycle with default networking, for comparison against --net=none.
run_bare()
{
  docker run --rm --entrypoint= "${IMG}" true
}

# The lifecycle as the runner actually invokes it.
run_runner_flags()
{
  # shellcheck disable=SC2086
  docker run --entrypoint= ${RUNNER_FLAGS} "${IMG}" true
}

probe_preflight cli_only
probe_preflight run_bare
probe_preflight run_runner_flags

probe_timeit_ms 'docker version (CLI + daemon)' "${RUNS}" cli_only
probe_timeit_ms 'docker run, bare'              "${RUNS}" run_bare
probe_timeit_ms 'docker run, runner flags'      "${RUNS}" run_runner_flags
