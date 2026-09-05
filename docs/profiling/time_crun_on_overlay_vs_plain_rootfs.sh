#!/usr/bin/env bash
# Price preparing a container's filesystem, which is work containerd's
# snapshotter does today and which a daemonless runner would have to do itself.
#
# time_oci_runtimes.sh timed crun against a rootfs already unpacked on disk, so
# it deliberately excluded that preparation. Its 2532us therefore understates a
# real per-test-run lifecycle by whatever an overlay mount costs, and that gap
# is the largest unknown in the case for dropping the docker daemon.
#
# Three spans are timed: the mount and umount alone, crun over a plain rootfs
# which is the sibling probe's baseline, and crun over an overlay-backed rootfs
# with the mount and umount inside the timed span. The third minus the second is
# what dropping the daemon does not recover.
#
# It found the mount and umount at 521us, and a whole lifecycle with them
# included at 3795us against 4143us without. That difference is negative, so it
# is below this probe's resolution rather than a speedup, and the reading is
# that preparing the filesystem costs about half a millisecond and is not where
# a daemonless runner's time would go. One 20-iteration sample on aarch64 under
# Docker Desktop, so it wants repeating on native amd64 Linux.
#
# The overlay lives on a tmpfs because overlayfs refuses an upperdir that is
# itself overlayfs, which is what a container's own root filesystem is.
#
# The two bundles share one unpacked rootfs, as lowerdir and as root.path, so
# the only difference between them is whether crun sees it through an overlay.
#
# Alpine-specific: it apk-adds crun and runc, runc only for its `spec`
# subcommand, which writes the config.json crun reads. Must run --privileged,
# because mounting overlayfs and creating containers need mount and cgroup
# privileges. Invoke with bash, not sh: busybox ash has neither C-style for
# loops nor EPOCHREALTIME.
#
#   docker run --rm --privileged \
#     --volume <repo>/runner/docs/profiling:/probe:ro alpine:3.24 \
#     sh -c 'apk add --no-cache bash > /dev/null && bash /probe/time_crun_on_overlay_vs_plain_rootfs.sh'
set -uo pipefail

readonly RUNS=20
readonly WORK=/work
readonly LOWER=${WORK}/lower
readonly UPPER=${WORK}/upper
readonly WORKDIR=${WORK}/workdir
readonly MERGED=${WORK}/merged
readonly PLAIN_BUNDLE=${WORK}/plain
readonly OVERLAY_BUNDLE=${WORK}/overlay
readonly RT_ROOT=/tmp/rt

apk add --no-cache crun runc > /dev/null 2>&1

echo "crun: $(crun --version | head -n1)"
echo "arch: $(uname -m)"
echo

# tmpfs, so that both sides of the overlay sit on a filesystem overlayfs will
# accept. Sized for one unpacked rootfs plus whatever a run writes over it.
mkdir -p "${WORK}"
mount -t tmpfs -o size=768M tmpfs "${WORK}"
mkdir -p "${LOWER}" "${UPPER}" "${WORKDIR}" "${MERGED}" \
         "${PLAIN_BUNDLE}" "${OVERLAY_BUNDLE}" "${RT_ROOT}"

# The rootfs both bundles run against, unpacked once from this container's own
# root filesystem, the same way time_oci_runtimes.sh builds its bundle.
tar -cf - --exclude=./proc --exclude=./sys --exclude=./dev \
          --exclude=./work --exclude=./tmp -C / . 2>/dev/null \
  | tar -xf - -C "${LOWER}" 2>/dev/null
mkdir -p "${LOWER}/proc" "${LOWER}/sys" "${LOWER}/dev" "${LOWER}/tmp"

# No tty is attached, and the payload must be trivial so what is measured is
# filesystem preparation rather than work. root.path is absolute, which is what
# lets the two bundles point at different roots without copying the rootfs.
write_config()
{
  local -r bundle="${1}"
  local -r root_path="${2}"
  ( cd "${bundle}" && runc spec )
  sed -i 's/"terminal": true/"terminal": false/' "${bundle}/config.json"
  sed -i 's/"sh"/"\/bin\/true"/' "${bundle}/config.json"
  sed -i "s|\"path\": \"rootfs\"|\"path\": \"${root_path}\"|" "${bundle}/config.json"
}

write_config "${PLAIN_BUNDLE}" "${LOWER}"
write_config "${OVERLAY_BUNDLE}" "${MERGED}"

# One overlay mount, which is what a per-test-run container's writable layer
# would be. Answers non-zero so a failure aborts rather than being timed.
overlay_up()
{
  mount -t overlay overlay \
    -o "lowerdir=${LOWER},upperdir=${UPPER},workdir=${WORKDIR}" "${MERGED}"
}

overlay_down()
{
  umount "${MERGED}"
}

# The mount and umount alone, with no container involved.
overlay_cycle()
{
  overlay_up && overlay_down
}

# One whole lifecycle over the plain rootfs. Container names are unique because
# crun keeps state under --root until the run deletes it.
crun_plain()
{
  crun --root "${RT_ROOT}" run --bundle "${PLAIN_BUNDLE}" "plain_${1}"
}

crun_overlay()
{
  crun --root "${RT_ROOT}" run --bundle "${OVERLAY_BUNDLE}" "overlay_${1}"
}

# One whole lifecycle including the filesystem preparation, which is the span a
# daemonless runner would actually pay per test-run.
overlay_lifecycle()
{
  overlay_up && crun_overlay "${1}" && overlay_down
}

# Prove each span works before timing it, so a failure cannot be averaged in as
# though it were fast.
preflight()
{
  local output
  if ! output="$("$@" 2>&1)"; then
    echo "ERROR: probe span failed, so its timing would be meaningless:" >&2
    echo "  $*" >&2
    echo "${output}" >&2
    exit 1
  fi
}

preflight overlay_cycle
preflight crun_plain preflight
preflight overlay_lifecycle preflight

# Each span is timed over the same iteration count, with output suppressed
# because it is not what is being measured.
time_span()
{
  local -r span_label="${1}"
  local -r span_fn="${2}"
  local -r t0=${EPOCHREALTIME/./}
  local iteration
  for (( iteration = 0; iteration < RUNS; iteration++ )); do
    "${span_fn}" "${iteration}" > /dev/null 2>&1
  done
  local -r t1=${EPOCHREALTIME/./}
  printf '%-44s %6s us\n' "${span_label}" "$(( (t1 - t0) / RUNS ))"
}

time_span 'overlay mount+umount, no container' overlay_cycle
time_span 'crun run, plain rootfs' crun_plain
time_span 'crun run, overlay mount+umount included' overlay_lifecycle
