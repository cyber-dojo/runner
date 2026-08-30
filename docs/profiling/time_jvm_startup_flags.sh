#!/usr/bin/env bash
# Price two JVM startup flags against the java-junit start-point, which is the
# cheapest thing available to a language whose traffic-light is dominated by JVM
# startup rather than by the kata's own work.
#
# -XX:TieredStopAtLevel=1 stops the JIT at C1, so nothing is ever compiled by
# C2. -XX:+UseSerialGC drops the parallel collector's startup. Both trade
# steady-state throughput for start-up time, which is the right trade for a
# process that lives for under a second and is thrown away.
#
# java-junit starts two JVMs per test-run, javac and then the JUnit console, so
# both are timed. javac takes the same flags through -J.
#
# The flags are worth about 86ms of a 597ms body, roughly 15%.
# -XX:TieredStopAtLevel=1 is the whole of that: on its own it takes the console
# from 314ms to 259ms, where -XX:+UseSerialGC on its own reaches 305ms, a
# difference this probe cannot tell from noise. UseSerialGC is timed here only
# to show it carries none of the win.
#
# An AOT cache is worth far more: javac 283ms to 108ms, and the console 314ms to
# 137ms, or 119ms with TieredStopAtLevel as well. That is 597ms to 227ms, about
# 62%, which is larger than everything else measured anywhere in this directory.
#
# That 62% is a learner's, not just a training run's. The cache is recorded
# against the kata as it arrives, and the probe then edits the source the way a
# learner does, recompiles, and reuses the same cache: javac holds at 113ms
# against 112ms, and the console at 140ms against 137ms. -XX:AOTMode=on, which
# refuses to start rather than falling back, still runs after that edit, so the
# cache is being used rather than quietly dropped.
#
# The reason it survives is that the JVM's own classpath is the console jar. The
# kata's classes reach JUnit through its --class-path argument and its own
# classloader, so they are never what the cache is validated against.
#
# What is still untested is a cache baked at image build time rather than
# recorded in the running container, which is how this would ship.
#
# One 10-iteration sample, warm, aarch64 under Docker Desktop. The image reports
# JDK 25, which is what makes -XX:AOTCacheOutput a single step; an older JDK
# needs the two-step AOTMode=record then AOTMode=create.
#
# The kata is copied out of the read-only mount because javac writes its class
# files beside the source. The JUnit console exits non-zero when the kata's
# tests fail, which a start-point's tests are meant to do, so the preflight here
# checks for output rather than for a zero exit.
#
#   docker run --rm --entrypoint="" \
#     --volume <repo>/runner/docs/profiling:/probe:ro \
#     --volume <start-points>/java-junit/start_point:/kata:ro \
#     ghcr.io/cyber-dojo-languages/java_junit:7aa5992 \
#     bash /probe/time_jvm_startup_flags.sh
set -uo pipefail

readonly RUNS=10
readonly KATA=/kata
readonly SANDBOX=/tmp/sandbox
readonly JAVAC_AOT=/tmp/javac.aot
readonly JUNIT_AOT=/tmp/junit.aot
readonly JUNIT_TIERED_AOT=/tmp/junit_tiered.aot

# Globbed rather than pinned, so the probe follows whatever jar the image
# carries instead of the version the start-point's script names.
JUNIT_JAR="$(ls /junit/junit-platform-console-standalone-*.jar | head -n1)"
readonly JUNIT_JAR
CLASSES=".:$(ls /junit/*.jar | tr '\n' ':')"
readonly CLASSES

echo "java: $(java -version 2>&1 | head -n1)"
echo "jar:  $(basename "${JUNIT_JAR}")"
echo "arch: $(uname -m)"
echo

mkdir -p "${SANDBOX}"
cp "${KATA}"/*.java "${SANDBOX}"
cd "${SANDBOX}" || exit 1

# The compile, exactly as the start-point's cyber-dojo.sh runs it, except that
# flags for javac's own JVM can be handed in through -J.
javac_with()
{
  javac "$@" -Xlint:preview -Xlint:unchecked -Xlint:deprecation -cp "${CLASSES}" ./*.java
}

javac_plain()   { javac_with; }
javac_flagged() { javac_with -J-XX:TieredStopAtLevel=1 -J-XX:+UseSerialGC; }
javac_aot()     { javac_with "-J-XX:AOTCache=${JAVAC_AOT}"; }

# The test run, exactly as the start-point's cyber-dojo.sh runs it. Flags go
# before -jar, which is where the JVM stops reading its own arguments.
junit_console()
{
  java "$@" \
    -jar "${JUNIT_JAR}" \
    execute \
    --class-path . \
    --disable-banner \
    --disable-ansi-colors \
    --details=tree \
    --details-theme=ascii \
    --scan-class-path
}

junit_plain()      { junit_console; }
junit_tiered()     { junit_console -XX:TieredStopAtLevel=1; }
junit_serial_gc()  { junit_console -XX:+UseSerialGC; }
junit_both()       { junit_console -XX:TieredStopAtLevel=1 -XX:+UseSerialGC; }
junit_aot()        { junit_console "-XX:AOTCache=${JUNIT_AOT}"; }
junit_aot_tiered() { junit_console "-XX:AOTCache=${JUNIT_TIERED_AOT}" -XX:TieredStopAtLevel=1; }

# Records an AOT cache by running the real workload once and writing what it
# loaded. A cache is only used by a JVM started the same way, so the tiered
# variant is trained under its own flag rather than sharing the plain cache.
#
# A build that fails leaves no cache, and the span that would use it is dropped
# rather than timed against a JVM silently falling back, which would report the
# baseline as though it were the cache.
# What a learner does between two presses: one edit to the source under test,
# here the one that turns the start-point's failing test green. It is what makes
# the timings after it a second press rather than a repeat of the first.
edit_kata()
{
  sed -i 's/6 \* 9/6 * 7/' "${SANDBOX}/Hiker.java"
}

# -XX:AOTMode=on refuses to start when the cache cannot be used, where the
# default falls back to no cache without saying so. Running the console under it
# is therefore the difference between a cache that still applies after the edit
# and one the timings would flatter. Test output is the signal, because exit
# status here reports the kata's tests rather than the JVM.
cache_still_applies()
{
  junit_console "-XX:AOTCache=${JUNIT_AOT}" -XX:AOTMode=on 2>&1 \
    | grep -q 'Test run finished'
}

# The written cache is the only signal that recording worked. Exit status says
# nothing here: the console reports the kata's failing test as non-zero, and
# recording also prints a Skipping line per class it will not archive, which is
# ordinary rather than a problem.
build_cache()
{
  local -r cache="${1}"
  shift
  "$@" > /dev/null 2>&1
  if [ -s "${cache}" ]; then
    return 0
  fi
  echo "SKIPPED: recorded no ${cache}, so that span is dropped rather than" >&2
  echo "         timed against a JVM silently falling back to no cache." >&2
  return 1
}

# The two spans need different proof that they worked, so they get one check
# each rather than one check that has to suit both.

# javac says nothing when it succeeds, so its exit status is the only signal.
preflight_compiles()
{
  local output
  if ! output="$("$@" 2>&1)"; then
    echo "ERROR: the compile failed, so its timing would be meaningless:" >&2
    echo "  $*" >&2
    echo "${output}" >&2
    exit 1
  fi
}

# The JUnit console's exit status says whether the kata's tests passed, and a
# start-point's tests are meant to fail, so output is the only signal here.
preflight_reports()
{
  local output
  output="$("$@" 2>&1)"
  if [ -z "${output}" ]; then
    echo "ERROR: the test run said nothing, so its timing would be meaningless:" >&2
    echo "  $*" >&2
    exit 1
  fi
}

# Each span over the same iteration count, reported in milliseconds because
# microseconds are more precision than a JVM start deserves.
time_span()
{
  local -r span_label="${1}"
  local -r span_fn="${2}"
  local -r t0=${EPOCHREALTIME/./}
  local iteration
  for (( iteration = 0; iteration < RUNS; iteration++ )); do
    "${span_fn}" > /dev/null 2>&1
  done
  local -r t1=${EPOCHREALTIME/./}
  printf '%-40s %6s ms\n' "${span_label}" "$(( (t1 - t0) / RUNS / 1000 ))"
}

preflight_compiles javac_plain
preflight_compiles javac_flagged
preflight_reports junit_plain

# Recorded after the compile above, so the console's training run sees the same
# class files on disk that the timed runs will.
build_cache "${JAVAC_AOT}" javac_with "-J-XX:AOTCacheOutput=${JAVAC_AOT}" \
  && readonly JAVAC_AOT_BUILT=yes
build_cache "${JUNIT_AOT}" junit_console "-XX:AOTCacheOutput=${JUNIT_AOT}" \
  && readonly JUNIT_AOT_BUILT=yes
build_cache "${JUNIT_TIERED_AOT}" junit_console \
  "-XX:AOTCacheOutput=${JUNIT_TIERED_AOT}" -XX:TieredStopAtLevel=1 \
  && readonly JUNIT_TIERED_AOT_BUILT=yes

time_span 'javac' javac_plain
time_span 'javac, both flags' javac_flagged
if [ -n "${JAVAC_AOT_BUILT:-}" ]; then
  time_span 'javac, AOTCache' javac_aot
fi
echo
time_span 'junit console' junit_plain
time_span 'junit console, TieredStopAtLevel=1' junit_tiered
time_span 'junit console, UseSerialGC' junit_serial_gc
time_span 'junit console, both flags' junit_both
if [ -n "${JUNIT_AOT_BUILT:-}" ]; then
  time_span 'junit console, AOTCache' junit_aot
fi
if [ -n "${JUNIT_TIERED_AOT_BUILT:-}" ]; then
  time_span 'junit console, AOTCache + TieredStopAtLevel=1' junit_aot_tiered
fi

# The caches were recorded against the kata as it arrived. A learner edits the
# source every press, so the figures above are only a learner's figures if a
# cache survives that edit. Everything below reuses the same caches, unrecorded,
# against changed source.
if [ -n "${JAVAC_AOT_BUILT:-}" ] && [ -n "${JUNIT_AOT_BUILT:-}" ]; then
  echo
  edit_kata
  preflight_compiles javac_aot
  if cache_still_applies; then
    echo 'after one edit, same caches: still used under -XX:AOTMode=on'
  else
    echo 'after one edit, same caches: NOT used, the JVM fell back'
  fi
  time_span 'javac, AOTCache, edited kata' javac_aot
  time_span 'junit console, AOTCache, edited kata' junit_aot
  if [ -n "${JUNIT_TIERED_AOT_BUILT:-}" ]; then
    time_span 'junit console, AOTCache + Tiered, edited' junit_aot_tiered
  fi
fi
