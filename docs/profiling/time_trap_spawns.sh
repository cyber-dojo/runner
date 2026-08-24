#!/usr/bin/env bash
# Time each process that the runner's exit trap spawns for every sandbox file.
#
# main_sh in source/server/home_files.rb walks the sandbox twice. Per file,
# remove_binary_files spawns bash -c, stat, file and grep; truncate_large_files
# then spawns bash -c and stat again. Six spawns per file, so the sum of these
# four figures times their multiplicity predicts the per-file cost.
#
# It found that `file --mime-encoding` is 49% of the per-file cost on a Debian
# based image and 77% on an Alpine one, because of the magic database `file`
# loads on every invocation. See cyber-dojo/faster-traffic-light.md, finding 1.
#
# The short flags below are deliberate: they replicate exactly what
# home_files.rb runs, so changing them would measure something else.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/probe_lib.sh"

probe_help_check "${1:-}" "Usage: time_trap_spawns.sh

Times bash, stat, file and grep inside the current image. Intended to be run
inside a language image, where the interesting variation lives:

  docker run --rm --entrypoint=\"\" --volume \$PWD:/probe:ro \\
    ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a \\
    bash /probe/time_trap_spawns.sh"

readonly RUNS=100
readonly TARGET=/tmp/probe_trap_spawns_target.txt

# Two bytes, because the trap treats anything smaller as text without invoking
# `file` on it, which would skip the very spawn this probe is timing.
printf 'xx' > "${TARGET}"

probe_environment
echo

probe_preflight bash -c true
probe_preflight stat -c%s "${TARGET}"
probe_preflight file --mime-encoding "${TARGET}"

probe_timeit 'bash -c true'          "${RUNS}" bash -c true
probe_timeit 'stat -c%s'             "${RUNS}" stat -c%s "${TARGET}"
probe_timeit 'file --mime-encoding'  "${RUNS}" file --mime-encoding "${TARGET}"
probe_timeit 'grep -q'               "${RUNS}" grep -q x "${TARGET}"

rm --force "${TARGET}"
