#!/usr/bin/env bash
set -Eeu -o pipefail
# Prices YJIT against the plain interpreter over runner's own payload parse.
#
# The ruby in sinatra-base has YJIT compiled in but not enabled: `ruby -v`
# reports +PRISM, and `ruby --yjit -v` reports +YJIT +PRISM. Nothing in web or
# runner turns it on, so the question is what the services give up by leaving
# it off, and what they would pay in memory for turning it on.
#
# Memory is why this probe reports RSS beside the timing rather than timing
# alone. YJIT holds an executable code region, and sinatra-base's own Dockerfile
# records aws-prod being OOM-killed on ruby 4.0.4 and needing its mem_limit
# raised. A speed-up bought with resident memory is not free here, so both
# numbers have to be read together.
#
# The work is TGZ.files over four payload profiles, which is what runner.rb
# does with a container's output. It is the largest piece of pure ruby CPU on
# the traffic-light path; see where-the-traffic-light-time-goes.txt, where the
# same parse is measured for the gzip question. YJIT needs warming, so the
# driver parses each payload repeatedly and reports the mean.
#
# One thread, because YJIT is a question about interpreter speed. The allocator
# question, which does turn on thread count, is
# compare_jemalloc_against_musl_malloc.sh.
#
# Both rows run in sinatra-base itself rather than a stock ruby image, because
# the ruby whose YJIT is in question is the one the services ship. On an arm64
# host that image is arm64 and so is not emulated; production is amd64, so
# treat the ratio as portable and the absolute numbers as not, exactly as the
# rest of this directory does.
#
# YJIT is not worth turning on for this path. Medians of five runs, arm64,
# one thread, microseconds per parse with the range beside them:
#
#   profile   interp us            yjit us              peak RSS delta
#   typical   182  (164-581)       1654 (1579-1762)     +0.9 MB
#   medium    1592 (1489-1776)     1807 (1778-1853)     +1.1 MB
#   large     2721 (2664-5800)     2695 (2544-2942)     +1.2 MB
#   ceiling   8141 (7695-9167)     7866 (7798-9526)     +0.8 MB
#
# Only ceiling is even nominally faster, by less than the run-to-run range, so
# nothing here is distinguishable from noise. typical is the one clear result
# and it goes the wrong way: at 40KB the compilation never earns itself back,
# and a kata that size is the common case rather than an edge.
#
# The reason is what the path is made of. TGZ.files is Zlib inflate and a walk
# over tar headers, so most of the time is in C and in string handling, and
# there is little ruby-level method dispatch for YJIT to compile away. A knob
# that speeds up the interpreter cannot help a path that barely uses it.
#
# The memory cost is small, under 1.3MB, so RSS is not what rules it out here.
#
# This says nothing about web, whose per-request work is sinatra routing and
# ERB rendering: that is ruby-level dispatch of exactly the kind YJIT targets,
# and it needs its own probe before YJIT is dismissed for the whole estate.
#
# An earlier round of these numbers showed YJIT 25-36% ahead. Another workload
# had the machine at the time. See probe_lib.sh's note on measuring conditions.
#
#   runner/docs/profiling/compare_yjit_against_interpreter.sh

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd "${MY_DIR}/../.." && pwd)"
source "${MY_DIR}/probe_lib.sh"

probe_help_check "${1:-}" \
"Usage: docs/profiling/compare_yjit_against_interpreter.sh [-h] [IMAGE]

Parses runner payloads with YJIT off and then on, in IMAGE, and prints the
microseconds per parse and the peak RSS for each.

Options:
  -h    Show this help

Example:
  docs/profiling/compare_yjit_against_interpreter.sh ghcr.io/cyber-dojo/sinatra-base:949edc1"

readonly IMAGE="${1:-ghcr.io/cyber-dojo/sinatra-base:949edc1}"
readonly PAYLOAD_DIR="$(mktemp -d)"
readonly THREADS=1

probe_environment
echo "image: ${IMAGE}"

probe_build_payloads "${PAYLOAD_DIR}"

# Runs the driver in IMAGE under the given RUBYOPT, which is the only
# difference between the two rows.
measure_under()
{
  local -r rubyopt="${1}"
  docker run --rm \
    --env RUBYOPT="${rubyopt}" \
    --volume "${REPO_DIR}:/repo:ro" \
    --volume "${PAYLOAD_DIR}:/payload:ro" \
    --entrypoint ruby "${IMAGE}" \
    /repo/docs/profiling/measure_parse_time_and_rss.rb "${THREADS}" \
      /payload/typical.tar /payload/medium.tar /payload/large.tar /payload/ceiling.tar
}

measure_under '--enable-frozen-string-literal'
echo
measure_under '--enable-frozen-string-literal --yjit'

rm -rf "${PAYLOAD_DIR}"
