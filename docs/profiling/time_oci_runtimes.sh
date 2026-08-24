#!/usr/bin/env bash
# Compare crun against runc on the same OCI bundle, to price the OCI runtime's
# share of the runner's per-press container-lifecycle cost.
#
# It found runc at 6226us and crun at 2532us for the whole lifecycle. crun is
# 2.5x faster, but that is only 3.7ms off a 92ms lifecycle, about 4%, so the OCI
# runtime is not where the fixed floor lives and a runtime swap is not worth
# doing for latency. See cyber-dojo/faster-traffic-light.md, finding 6.
#
# This probe is kept to stop the runtime-swap idea being re-proposed, and to be
# re-run on native Linux, where the ratio may differ from Docker Desktop's VM.
#
# Alpine-specific: it apk-adds crun and runc. Must run --privileged, because
# creating containers needs cgroup and mount privileges. Invoke with bash, not
# sh: busybox ash has neither C-style for loops nor EPOCHREALTIME.
set -uo pipefail

readonly RUNS=20
readonly BUNDLE=/bundle
readonly RT_ROOT=/tmp/rt

apk add --no-cache crun runc > /dev/null 2>&1

echo "crun: $(crun --version | head -n1)"
echo "runc: $(runc --version | head -n1)"
echo "arch: $(uname -m)"
echo

# Build a minimal OCI bundle from this container's own root filesystem. The
# rootfs is already unpacked on disk, so this measures the runtime alone and
# excludes the snapshot preparation that containerd does per container.
mkdir -p "${BUNDLE}/rootfs" "${RT_ROOT}"
tar -cf - --exclude=./proc --exclude=./sys --exclude=./dev \
          --exclude=./bundle --exclude=./tmp -C / . 2>/dev/null \
  | tar -xf - -C "${BUNDLE}/rootfs" 2>/dev/null
mkdir -p "${BUNDLE}/rootfs/proc" "${BUNDLE}/rootfs/sys" \
         "${BUNDLE}/rootfs/dev" "${BUNDLE}/rootfs/tmp"

cd "${BUNDLE}"
runc spec

# No tty is attached, and the payload must be trivial so what is measured is
# runtime overhead rather than work.
sed -i 's/"terminal": true/"terminal": false/' config.json
sed -i 's/"sh"/"\/bin\/true"/' config.json

# Prove each runtime works before timing it, so a failure cannot be averaged in
# as though it were fast.
for rt in runc crun; do
  if ! out="$(${rt} --root ${RT_ROOT} run --bundle "${BUNDLE}" "preflight_${rt}" 2>&1)"; then
    echo "ERROR: ${rt} could not run the bundle, so its timing is meaningless:" >&2
    echo "${out}" >&2
    exit 1
  fi
done

for rt in runc crun; do
  t0=${EPOCHREALTIME/./}
  for (( i = 0; i < RUNS; i++ )); do
    ${rt} --root ${RT_ROOT} run --bundle "${BUNDLE}" "bench_${rt}_${i}" > /dev/null 2>&1
  done
  t1=${EPOCHREALTIME/./}
  printf '%-6s create+start+wait+delete %6s us\n' "${rt}" "$(( (t1 - t0) / RUNS ))"
done
