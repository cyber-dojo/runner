#!/usr/bin/env bash
# Shared helpers for the timing probes in this directory.
#
# The probes exist to decompose the latency of a cyber-dojo traffic-light. Each
# one states in its own header what it measures and what it found.
#
# Timing uses bash's EPOCHREALTIME builtin rather than date(1). Removing its dot
# yields integer microseconds, and a builtin costs no process spawn, which
# matters because several probes measure process spawn cost itself.

# Print usage and exit 0 when the first argument is -h. Call as:
#   probe_help_check "${1:-}" "usage text"
probe_help_check()
{
  local -r arg="${1}"
  local -r usage="${2}"
  if [ "${arg}" = '-h' ]; then
    echo "${usage}"
    exit 0
  fi
}

# Run a command once, loudly, so a broken invocation fails the probe rather than
# being timed as if it were fast. Shows the command's own output on failure.
probe_preflight()
{
  local output
  if ! output="$("$@" 2>&1)"; then
    echo "ERROR: probe command failed, so its timing would be meaningless:" >&2
    echo "  $*" >&2
    echo "${output}" >&2
    exit 1
  fi
}

# Time a command over N iterations and print the mean. Output is suppressed
# because it is not what is being measured; a mid-loop failure aborts the probe
# via set -e rather than being silently averaged in.
# Call as: probe_timeit LABEL RUNS COMMAND...
probe_timeit()
{
  local -r label="${1}"
  local -r runs="${2}"
  shift 2
  local -r t0=${EPOCHREALTIME/./}
  local i
  for (( i = 0; i < runs; i++ )); do
    "$@" > /dev/null 2>&1
  done
  local -r t1=${EPOCHREALTIME/./}
  printf '%-42s %6s us\n' "${label}" "$(( (t1 - t0) / runs ))"
}

# As probe_timeit, but reports milliseconds, for spans where microseconds are
# more precision than the measurement deserves.
probe_timeit_ms()
{
  local -r label="${1}"
  local -r runs="${2}"
  shift 2
  local -r t0=${EPOCHREALTIME/./}
  local i
  for (( i = 0; i < runs; i++ )); do
    "$@" > /dev/null 2>&1
  done
  local -r t1=${EPOCHREALTIME/./}
  printf '%-42s %6s ms\n' "${label}" "$(( (t1 - t0) / runs / 1000 ))"
}

# Describe where the probe is running, so results from different architectures
# are not accidentally compared. Emulation of the runner image on an arm64 host
# inflated an earlier round of these measurements by about 72ms per test-run.
probe_environment()
{
  # -m rather than --machine: these probes run on the host as well as inside
  # Linux containers, and macOS ships BSD uname, which has no long options.
  echo "arch: $(uname -m)"
}
