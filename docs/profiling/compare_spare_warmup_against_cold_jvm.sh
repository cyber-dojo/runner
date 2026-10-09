#!/usr/bin/env bash
set -Eeu -o pipefail
# Asks what a spare container could usefully do to a JVM language before the
# learner's test-run arrives, using java-junit, whose traffic-light is
# dominated by JVM startup rather than by the kata's own work.
#
# The pool in spare_pool.rb hands a test-run a container that is already
# created and started, which is worth about 52ms (see
# where-the-traffic-light-time-goes.txt). The question here is whether the
# spare can go further and warm the language itself while nobody is waiting.
#
# There is a reason to doubt that it can. A test-run spawns a NEW jvm, so
# nothing a previous jvm in that container learned survives into the
# learner's run: no JIT state, no loaded classes. What can survive is on
# disk, either as kernel page cache, which the host shares between all
# containers off the same image and so is not the spare's to give, or as an
# AOT cache file, which the image already ships.
#
# So the two rows are:
#
#   first run in this container      what a spare offers today
#   runs 2..6, container warm        what a previous jvm in the same
#                                    container leaves behind, which is the
#                                    "warm the interpreter" idea
#
# Everything runs in one fresh container, so the first row is genuinely the
# first run in it. The host page cache is warm throughout, which is the
# production case: a node that has run this image before. What the rows
# differ by is therefore per-container state alone.
#
# A warm-up run in the spare is worth about 29ms, roughly 14%. Medians of
# five runs, arm64 under Docker Desktop, JDK 26, one whole test-run meaning
# the kata's cyber-dojo.sh, compile and tests together:
#
#   first run in this container      209 ms    (192-286)
#   runs 2..6, container warm        180 ms    (174-313, clustered 174-182)
#
# Every first run came in above the warm median, so the gap is consistent
# rather than noise, though the warm rows carry occasional outliers near
# 300ms which no single run would reveal.
#
# What the second run skips is not JIT state or loaded classes: those die
# with the process, and every test-run is a new jvm. It is first-touch, the
# jvm's first mmap of the jars and the AOT caches into this container's mount
# namespace and the tmpfs pages being faulted in. That is a per-container
# cost, which is the kind a spare can pay while nobody is waiting.
#
# 29ms is small beside the 52ms the pool itself saves, but it is additive and
# it costs the learner nothing, because an idle spare has the time.
#
# There is no AOT cache to record here, because the image already ships one.
# java-junit's Dockerfile.base runs record_aot_caches.sh at build time
# against a throwaway kata, leaving /aot/javac.aot and /aot/junit-console.aot,
# and the start-point's cyber-dojo.sh passes -XX:AOTCache for both alongside
# -XX:TieredStopAtLevel=1 and -XX:+UseSerialGC. The 62% that
# time_jvm_startup_flags.sh measured is therefore already in production, and
# the open question it left, a cache baked at image build time, is answered:
# it is what ships.
#
# An earlier version of this probe reimplemented the compile and the test run
# instead of invoking cyber-dojo.sh. That left out the AOT flags and the
# collector flags, putting the baseline at 777ms against the 209ms measured
# here, and made recording a cache look worth 546ms when the image had
# already banked it. Invoking the artefact is what keeps a probe honest; a
# reimplementation measures a configuration nothing ships.
#
#   runner/docs/profiling/compare_spare_warmup_against_cold_jvm.sh

readonly MY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${MY_DIR}/probe_lib.sh"

probe_help_check "${1:-}" \
"Usage: docs/profiling/compare_spare_warmup_against_cold_jvm.sh [-h] [IMAGE] [START_POINT]

Runs the kata's own cyber-dojo.sh six times in a fresh container and times
each, so the first run can be compared against the five that follow it. The
gap is what a spare could take off the learner by running once in advance.

Options:
  -h    Show this help

Example:
  docs/profiling/compare_spare_warmup_against_cold_jvm.sh ghcr.io/cyber-dojo-languages/java_junit:0e17080"

readonly IMAGE="${1:-ghcr.io/cyber-dojo-languages/java_junit:0e17080}"
readonly START_POINT="${2:-${HOME}/repos/cyber-dojo-start-points/java-junit/start_point}"

probe_environment
echo "image: ${IMAGE}"
echo "kata:  ${START_POINT}"
echo

# Runs the inner script in a fresh container in the given mode. The kata is
# mounted read-only and copied aside inside, because javac writes its class
# files beside the source.
measure_runs()
{
  docker run --rm \
    --tmpfs /tmp:exec,size=250M,mode=1777 \
    --volume "${MY_DIR}:/probe:ro" \
    --volume "${START_POINT}:/kata:ro" \
    --entrypoint='' "${IMAGE}" \
    bash /probe/measure_jvm_run_after_warmup.sh 6
}

measure_runs
