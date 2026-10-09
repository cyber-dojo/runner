#!/usr/bin/env bash
set -uo pipefail
# Times java-junit test-runs inside one container, by running the kata's own
# cyber-dojo.sh rather than a copy of the commands in it.
#
# Running the real script is the point. The image bakes an AOT cache for each
# of the two jvms into /aot when it is built, and cyber-dojo.sh passes
# -XX:AOTCache for both alongside -XX:TieredStopAtLevel=1 and -XX:+UseSerialGC.
# A probe that reimplements the compile and the test run leaves all of that
# out and measures a configuration nothing ships, which makes the baseline
# look far worse than production and any improvement look far larger.
#
# Run by compare_spare_warmup_against_cold_jvm.sh, in a fresh container, so
# that the first row is genuinely the first run in that container.
#
# Usage: measure_jvm_run_after_warmup.sh [RUNS]

readonly KATA=/kata
readonly SANDBOX=/tmp/sandbox
readonly RUNS="${1:-6}"

export CYBER_DOJO_SANDBOX="${SANDBOX}"

mkdir -p "${SANDBOX}"
cp -r "${KATA}"/. "${SANDBOX}"

readonly RUN_LOG=/tmp/run.log

# Runs the kata's own cyber-dojo.sh, which is what a learner's press of [test]
# runs. A start-point's tests are meant to fail, so a non-zero exit is the
# expected result and says nothing about the probe. The output is kept rather
# than discarded so that the first run can be checked for having done
# anything, which a separate preflight run could not do without warming the
# container it is about to measure.
test_run()
{
  bash "${SANDBOX}/cyber-dojo.sh" > "${RUN_LOG}" 2>&1
  return 0
}

# Prints the milliseconds one invocation of its arguments took. EPOCHREALTIME
# is a bash builtin, so timing costs no process spawn.
time_once()
{
  local -r t0=${EPOCHREALTIME/./}
  "$@"
  local -r t1=${EPOCHREALTIME/./}
  echo $(( (t1 - t0) / 1000 ))
}

echo "files: $(ls "${SANDBOX}" | tr '\n' ' ')"

echo "first run in this container      $(time_once test_run) ms"

# Checked after the first run rather than before it, because a preflight run
# would warm the very container whose cold row is being measured. An empty
# log means the script did nothing, so every row below it is meaningless.
if [ ! -s "${RUN_LOG}" ]; then
  echo 'ERROR: cyber-dojo.sh produced no output, so its timing is meaningless' >&2
  exit 1
fi
for (( i = 1; i < RUNS; i++ )); do
  echo "run $(( i + 1 )), container already warm   $(time_once test_run) ms"
done
