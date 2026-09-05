#!/usr/bin/env bash
# Price one containerd snapshot Prepare and Remove, which is what a runner would
# pay per test-run if it kept containerd as its image store and drove crun
# itself.
#
# ../dropping-the-docker-daemon.md proposes replacing the daemon outright, which
# means owning the rootfs store and its garbage collection. Keeping containerd
# for the image plane instead keeps its lease-based GC and lets a socket proxy
# be restricted to images and snapshots, since the runner would never ask
# anything to run a container. The cost of that choice is one round trip per
# test-run, and this probe is what says whether that cost matters against the
# roughly 92ms lifecycle being removed.
#
# It found the round trip free: 5215us for prepare and rm against a 5206us floor
# of two calls that do nothing, a 9us difference this probe cannot distinguish
# from noise. The 5.2ms is two ctr process startups, which a runner speaking
# gRPC from its own process would not pay at all.
#
# So keeping containerd as the image plane costs nothing per test-run. The
# lease-based GC and the restricted socket proxy it allows are not paid for in
# latency, which is the opposite of what was assumed before this ran.
#
# One thing this does not measure, and which is not zero. prepare answers the
# mount rather than performing it, so applying that mount is still the caller's
# work, and time_crun_on_overlay_vs_plain_rootfs.sh puts it at about 521us. The
# snapshot here also has no parent, so nothing is stacked under it; a real
# image's layers would give the mount more lowerdirs.
#
# 20 iterations, aarch64 under Docker Desktop, containerd's root on tmpfs.
#
# What is subtracted and why: each ctr call is a process spawn plus a gRPC
# round trip, and a runner would speak gRPC from inside its own process with no
# spawn at all. Timing prepare+rm alone would therefore charge the design for
# two CLI startups it would never pay. So a floor of two ctr calls that do
# almost nothing is timed as well, and the difference is the part that is really
# Prepare and Remove.
#
# containerd's root goes on a tmpfs because the overlay snapshotter refuses an
# upperdir that is itself overlayfs, which is what a container's own root
# filesystem is.
#
# Alpine-specific: it apk-adds containerd and containerd-ctr. Must run
# --privileged, because the snapshotter mounts overlayfs. Invoke with bash, not
# sh: busybox ash has neither C-style for loops nor EPOCHREALTIME.
#
#   docker run --rm --privileged \
#     --volume <repo>/runner/docs/profiling:/probe:ro alpine:3.24 \
#     sh -c 'apk add --no-cache bash > /dev/null && bash /probe/time_containerd_snapshot_prepare.sh'
set -uo pipefail

readonly RUNS=20
readonly WORK=/work
readonly CTR_ROOT=${WORK}/containerd
readonly CTR_STATE=/run/containerd
readonly CTR_SOCK=${CTR_STATE}/containerd.sock

apk add --no-cache containerd containerd-ctr > /dev/null 2>&1

echo "containerd: $(containerd --version | head -n1)"
echo "arch: $(uname -m)"
echo

mkdir -p "${WORK}"
mount -t tmpfs -o size=512M tmpfs "${WORK}"
mkdir -p "${CTR_ROOT}" "${CTR_STATE}"

containerd --root "${CTR_ROOT}" --state "${CTR_STATE}" > /tmp/containerd.log 2>&1 &

# The daemon is not ready the moment it is launched, and timing against a socket
# that is not listening yet would measure the wait rather than the work.
wait_for_socket()
{
  local attempt
  for (( attempt = 0; attempt < 100; attempt++ )); do
    if ctr --address "${CTR_SOCK}" version > /dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done
  echo "ERROR: containerd did not start, so nothing below would be meaningful:" >&2
  cat /tmp/containerd.log >&2
  exit 1
}

wait_for_socket

# Two calls that reach containerd and do almost nothing, matching the call count
# of the span below so the subtraction is like for like.
floor_pair()
{
  ctr --address "${CTR_SOCK}" snapshots ls > /dev/null 2>&1
  ctr --address "${CTR_SOCK}" snapshots ls > /dev/null 2>&1
}

# One snapshot's whole life: the mount a test-run would write into, and its
# removal. No parent, so this is the snapshotter's bookkeeping and mount rather
# than the cost of stacking an image's layers under it.
prepare_and_remove()
{
  local -r key="bench_${1}"
  ctr --address "${CTR_SOCK}" snapshots prepare --mounts "${key}" > /dev/null 2>&1
  ctr --address "${CTR_SOCK}" snapshots rm "${key}" > /dev/null 2>&1
}

# Proves the span works before it is timed, so a snapshotter that refuses is not
# averaged in as though it were fast. --mounts is what makes prepare print the
# mount it produced; without it a successful prepare says nothing, and silence
# would read here as a failure.
preflight()
{
  local output
  output="$(ctr --address "${CTR_SOCK}" snapshots prepare --mounts preflight_key 2>&1)"
  if [ -z "${output}" ]; then
    echo "ERROR: snapshot prepare produced no mounts, so its timing would be" >&2
    echo "       meaningless. containerd log follows:" >&2
    cat /tmp/containerd.log >&2
    exit 1
  fi
  ctr --address "${CTR_SOCK}" snapshots rm preflight_key > /dev/null 2>&1
}

preflight

time_span()
{
  local -r span_label="${1}"
  local -r span_fn="${2}"
  local -r t0=${EPOCHREALTIME/./}
  local iteration
  for (( iteration = 0; iteration < RUNS; iteration++ )); do
    "${span_fn}" "${iteration}"
  done
  local -r t1=${EPOCHREALTIME/./}
  printf '%-44s %6s us\n' "${span_label}" "$(( (t1 - t0) / RUNS ))"
}

time_span 'two ctr calls, the CLI floor' floor_pair
time_span 'snapshot prepare + rm, floor included' prepare_and_remove
