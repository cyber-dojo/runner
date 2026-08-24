#!/usr/bin/env bash
# Report whether this image's gzip(1) accepts -1, and whether what it writes
# still round-trips.
#
# time_tgz_vs_tar_emit.sh shows -1 costing about a third of the default level
# while keeping most of the compression, which makes it the cheap way to keep
# gzip's CRC32 and length trailer. That measurement was taken on one image, so
# it says nothing about portability. This probe is the one that does: it prints
# a single line per image so a host-side loop over every image reads as a table.
#
# Portability here is not a given. GNU gzip rejects -0, and the Alpine images
# ship busybox applets whose flag support differs from GNU's, exactly as
# busybox xargs rejects --null while accepting -0.
#
# Short options throughout, against this repo's usual preference for long ones:
# busybox rejects --version, --delete, --bytes and --silent outright, and a
# probe that dies on the very images whose portability is in question reports
# nothing where it matters most.
set -eu

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/probe_lib.sh"

probe_help_check "${1:-}" "Usage: check_gzip_level_1_flag_support.sh

Prints one line: OS, gzip version, whether -1 and -0 are accepted, and whether
a -1 stream round-trips. Exits non-zero if -1 fails or the round-trip differs.
Run inside a language image:

  docker run --rm --entrypoint=\"\" --volume \$PWD:/probe:ro \\
    ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd \\
    bash /probe/check_gzip_level_1_flag_support.sh

To survey every locally pulled language image:

  for img in \$(docker images --format '{{.Repository}}:{{.Tag}}' \\
                | grep cyber-dojo-languages | sort); do
    printf '%-58s ' \"\${img}\"
    docker run --rm --entrypoint=\"\" --volume \$PWD:/probe:ro \"\${img}\" \\
      bash /probe/check_gzip_level_1_flag_support.sh 2>&1 | tail -1
  done"

readonly DIR=/tmp/probe_gzip_level_1_flag_support

rm -rf "${DIR}"
mkdir -p "${DIR}"
cd "${DIR}"

# Real text rather than zeroes, so a level that silently stores rather than
# deflates is still visible in the byte count.
cat /etc/services /etc/passwd /etc/group > plain.txt 2>/dev/null || true
if [ ! -s plain.txt ]; then
  i=0
  while [ "${i}" -lt 500 ]; do
    echo 'the quick brown fox jumps over the lazy dog' >> plain.txt
    i=$(( i + 1 ))
  done
fi

os='unknown'
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  os="${ID:-unknown}${VERSION_ID:+:${VERSION_ID}}"
fi

# busybox gzip has no --version and exits non-zero when given one, so the
# version is whatever the first line of that attempt says, and the applet is
# named separately from the version it claims.
version="$(gzip --version 2>&1 | head -1 | tr -d '\n' || true)"
case "${version}" in
  *BusyBox*|*busybox*|*'unrecognized option'*|*'invalid option'*|*Usage*)
    version="busybox ($(busybox 2>&1 | head -1 | cut -d' ' -f1-2 || echo unknown))"
    ;;
esac

# Reports whether gzip accepts the level at all, separately from whether what
# it wrote can be read back, because those fail in different ways.
level_accepted()
{
  gzip "${1}" -c plain.txt > /dev/null 2>&1
}

if level_accepted -1; then level_1=yes; else level_1=no; fi
if level_accepted -0; then level_0=yes; else level_0=no; fi

round_trip=n/a
ratio=n/a
if [ "${level_1}" = yes ]; then
  gzip -1 -c plain.txt > level1.gz
  if gzip -d -c level1.gz | cmp -s - plain.txt; then
    round_trip=ok
  else
    round_trip=DIFFERS
  fi
  plain_bytes=$(wc -c < plain.txt)
  gz_bytes=$(wc -c < level1.gz)
  if [ "${gz_bytes}" -gt 0 ]; then
    ratio="$(( plain_bytes / gz_bytes ))x"
  fi
fi

printf '%-14s %-34s -1=%-4s -0=%-4s round_trip=%-8s ratio=%s\n' \
  "${os}" "${version}" "${level_1}" "${level_0}" "${round_trip}" "${ratio}"

cd /
rm -rf "${DIR}"

[ "${level_1}" = yes ] && [ "${round_trip}" = ok ]
