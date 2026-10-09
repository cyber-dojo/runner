#!/usr/bin/env bash
set -Eeu -o pipefail
# Prices jemalloc against musl's own allocator over runner's payload parse.
#
# sinatra-base is built on ruby:alpine, so ruby links libc.musl directly:
#
#   ldd $(which ruby)
#     libc.musl-aarch64.so.1 => /lib/ld-musl-aarch64.so.1
#
# and no jemalloc is present in the image. musl's allocator is tuned for small
# size over throughput, which is the opposite of what a long-lived ruby server
# wants, and it is the usual reason ruby-on-alpine is slower and holds more
# memory than the same ruby on glibc. Whether that is true of THIS workload is
# what the probe is for; it is an assumption until these rows exist.
#
# jemalloc arrives by LD_PRELOAD rather than by rebuilding ruby, which is what
# makes this measurable before committing to anything. If the numbers justify
# it, shipping it is an apk add plus the same LD_PRELOAD in the image, not a
# recompile.
#
# RSS is reported beside the timing because fragmentation, not speed, is the
# likelier win here: sinatra-base's Dockerfile records aws-prod OOM kills and
# a raised mem_limit, so an allocator that returns memory more readily may be
# worth more than one that is faster. Read both columns.
#
# Thread count is the variable that matters, so the probe sweeps it. An
# allocator's behaviour on one thread is not its behaviour under several, and
# runner's puma serves on 8 (see config/puma.rb). Note ruby's GVL means the
# threads are not all allocating at once, which is a reason to expect a
# smaller effect here than the ruby-on-alpine folklore suggests. Zlib inflate
# does release the GVL, so the parse is not fully serialised either. The sweep
# is what settles it.
#
# The work is TGZ.files over four payload profiles, which is what runner.rb
# does with a container's output, so the allocation mix is production's.
#
# jemalloc is faster on every profile and at both thread counts, and it holds
# a great deal more memory for it. Medians of five runs, arm64:
#
#                 parse us                 peak RSS KB
#   profile    libc   jemalloc  delta    libc   jemalloc  delta
#   1 thread
#   typical     206        136   -34%   25160      27968   +11%
#   medium     1699       1391   -18%   34168      42536   +24%
#   large      2884       2429   -16%   54568      70204   +29%
#   ceiling    8756       7062   -19%   68036      87900   +29%
#   8 threads
#   typical     590        370   -37%   27968      38152   +36%
#   medium     3669       1948   -47%   47824      81596   +71%
#   large      4504       3226   -28%   93480     137556   +47%
#   ceiling   10331       9305   -10%  108064     204248   +89%
#
# The speed-up is real and larger than the run-to-run range, so musl's
# allocator is indeed what the ruby-on-alpine folklore says it is, even under
# the GVL. Note the 8-thread rows improve more than the 1-thread rows, which
# is the concurrency the GVL does not serialise: Zlib releases it to inflate.
#
# The memory is what decides this, and it decides against. At 8 threads the
# ceiling payload takes peak RSS from 108MB to 204MB, an extra 96MB per
# worker, and runner runs two workers on 8 threads each (config/puma.rb).
# sinatra-base's Dockerfile records aws-prod already being OOM-killed and
# having its mem_limit raised. Buying 10-47% of a few milliseconds with that
# much resident memory is the wrong way round on a memory-bound node.
#
# Capping the arenas does not rescue it. Medians of five runs at 8 threads,
# the ceiling payload, which is where the memory was worst:
#
#   config                 parse us   peak RSS KB   vs libc
#   libc                      10404        109420        -
#   jemalloc (default)         9435        193220      +77%
#   jemalloc narenas:1         9369        165668      +51%
#   jemalloc narenas:2         9467        170464      +56%
#   jemalloc narenas:4         9408        189380      +73%
#
# narenas:1 costs none of the speed and recovers about a fifth of the excess,
# leaving jemalloc still holding half as much again as musl. So per-thread
# arenas are not where the memory goes, which is what the sweep was written to
# find out. What is left is retained dirty pages: jemalloc holds freed pages
# rather than returning them to the OS, governed by dirty_decay_ms and
# muzzy_decay_ms.
#
# Setting both decays to 0 does recover the memory, and it takes the speed
# with it. Medians of five runs, 8 threads, the ceiling payload:
#
#   config                              parse us   peak RSS KB
#   libc (musl)                            10037        105484
#   jemalloc                                9140        189960
#   jemalloc narenas:1                      9507        170108
#   jemalloc dirty+muzzy_decay_ms:0        10457        119536
#   jemalloc narenas:1 + both decays:0     11073        115340
#
# Read down the two columns together: every configuration that is faster than
# musl holds much more memory, and every configuration that holds about as
# much memory as musl is slower than it. jemalloc's advantage on this workload
# IS the retained memory, so it cannot be kept while giving the memory back.
#
# That rules jemalloc out on the mechanism rather than on a threshold, which
# is worth more than the numbers: it does not need revisiting when the node's
# memory budget changes. It would need revisiting if the workload changed to
# one whose allocation is genuinely concurrent, since the GVL is what keeps
# musl's weakness small here.
#
#   runner/docs/profiling/compare_jemalloc_against_musl_malloc.sh

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_DIR="$(cd "${MY_DIR}/../.." && pwd)"
source "${MY_DIR}/probe_lib.sh"

probe_help_check "${1:-}" \
"Usage: docs/profiling/compare_jemalloc_against_musl_malloc.sh [-h] [IMAGE]

Parses runner payloads in IMAGE under musl malloc and then under jemalloc, at
1 and 8 threads, then sweeps jemalloc's narenas and page-decay settings at 8
threads. Prints the microseconds per parse and the peak RSS for each.

Options:
  -h    Show this help

Example:
  docs/profiling/compare_jemalloc_against_musl_malloc.sh ghcr.io/cyber-dojo/sinatra-base:949edc1"

readonly IMAGE="${1:-ghcr.io/cyber-dojo/sinatra-base:949edc1}"
readonly PAYLOAD_DIR="$(mktemp -d)"
readonly JEMALLOC_IMAGE=sinatra-base-jemalloc:probe
readonly RUBYOPT='--enable-frozen-string-literal'

probe_environment
echo "image: ${IMAGE}"

probe_build_payloads "${PAYLOAD_DIR}"

# Build a throwaway image with jemalloc added. The probe builds it rather than
# apk-adding inside each timed run, so no network fetch lands in a measurement
# and both allocators are measured in the same filesystem.
build_jemalloc_image()
{
  printf '%s\n' \
    "FROM ${IMAGE}" \
    'USER root' \
    'RUN apk add --no-cache jemalloc' \
  | docker build --quiet --tag "${JEMALLOC_IMAGE}" -
}

# Runs the driver at the given thread count, in the given image, optionally
# preloading jemalloc under the given MALLOC_CONF. Those three are the only
# differences between the rows.
measure_under()
{
  local -r image="${1}" preload="${2}" malloc_conf="${3}" threads="${4}"
  docker run --rm \
    --env RUBYOPT="${RUBYOPT}" \
    --env LD_PRELOAD="${preload}" \
    --env MALLOC_CONF="${malloc_conf}" \
    --volume "${REPO_DIR}:/repo:ro" \
    --volume "${PAYLOAD_DIR}:/payload:ro" \
    --entrypoint ruby "${image}" \
    /repo/docs/profiling/measure_parse_time_and_rss.rb "${threads}" \
      /payload/typical.tar /payload/medium.tar /payload/large.tar /payload/ceiling.tar
}

probe_preflight build_jemalloc_image

readonly JEMALLOC_SO=/usr/lib/libjemalloc.so.2

for threads in 1 8; do
  measure_under "${IMAGE}" '' '' "${threads}"
  echo
  measure_under "${JEMALLOC_IMAGE}" "${JEMALLOC_SO}" '' "${threads}"
  echo
done

# Sweep jemalloc's tuning at 8 threads, which is where its memory grew. 8
# threads is runner's puma setting, so these are the rows that decide whether
# jemalloc is affordable at all.
#
# narenas caps the per-thread arenas. The decay settings control how long
# jemalloc holds freed pages before returning them to the OS; zero returns
# them eagerly, trading syscalls for residency, which is the right direction
# on a node that runs out of memory before it runs out of CPU.
readonly TUNINGS=(
  'narenas:1'
  'narenas:2'
  'narenas:4'
  'dirty_decay_ms:0,muzzy_decay_ms:0'
  'narenas:1,dirty_decay_ms:0,muzzy_decay_ms:0'
)

for tuning in "${TUNINGS[@]}"; do
  measure_under "${JEMALLOC_IMAGE}" "${JEMALLOC_SO}" "${tuning}" 8
  echo
done

docker image rm --force "${JEMALLOC_IMAGE}" > /dev/null
rm -rf "${PAYLOAD_DIR}"
