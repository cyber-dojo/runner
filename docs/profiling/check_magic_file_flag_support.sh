#!/usr/bin/env bash
# Report whether this image's file(1) accepts --magic-file, and whether using it
# changes the binary/non-binary verdict.
#
# time_file_without_magic_db.sh shows `--magic-file /dev/null` making
# `--mime-encoding` far cheaper, and compare_magic_db_verdicts.sh shows it
# deciding the same files are binary. Both were run on two images only, so
# neither says the flag is portable across the language images. This probe is the
# one that does: it prints a single line per image so a host-side loop over every
# image can be read as a table.
#
# The short form is reported alongside the long one because portability here is
# not a given. faster-traffic-light.md finding 1 records `xargs --null` failing on
# the busybox xargs the Alpine images ship, where `xargs -0` works, so a long
# option is exactly the kind of thing that does not survive every image.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/probe_lib.sh"

probe_help_check "${1:-}" "Usage: check_magic_file_flag_support.sh

Prints one line: OS, file version, whether the long and short magic-file flags
work, and whether the verdicts still match. Exits non-zero if the long flag fails
or a verdict changes. Run inside a language image:

  docker run --rm --entrypoint=\"\" --volume \$PWD:/probe:ro \\
    ghcr.io/cyber-dojo-languages/csharp_nunit:70e19ed \\
    bash /probe/check_magic_file_flag_support.sh

To survey every locally pulled language image:

  for img in \$(docker images --format '{{.Repository}}:{{.Tag}}' \\
                | grep cyber-dojo-languages | sort); do
    printf '%-58s ' \"\${img}\"
    docker run --rm --entrypoint=\"\" --volume \$PWD:/probe:ro \"\${img}\" \\
      bash /probe/check_magic_file_flag_support.sh 2>&1 | tail -1
  done"

readonly DIR=/tmp/probe_magic_file_flag_support

rm --recursive --force "${DIR}"
mkdir --parents "${DIR}"
cd "${DIR}"

# One text file and one binary, which is enough to catch a flag that is accepted
# but changes the answer. The wide corpus lives in compare_magic_db_verdicts.sh.
printf 'hello world\n' > text.txt
cp "$(command -v ls)" elf.bin

os='unknown'
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  os="${ID:-unknown}${VERSION_ID:+:${VERSION_ID}}"
fi

version="$(file --version 2>&1 | head -1 | tr --delete '\n')"

# Reports whether file(1) accepts the flag at all, separately from whether the
# answer it then gives is right, because those fail in different ways.
flag_works()
{
  file "$@" --mime-encoding --brief text.txt > /dev/null 2>&1
}

if flag_works --magic-file /dev/null; then long_flag=yes; else long_flag=no; fi
if flag_works -m /dev/null;           then short_flag=yes; else short_flag=no; fi

verdicts=n/a
if [ "${long_flag}" = yes ]; then
  verdicts=match
  for f in text.txt elf.bin; do
    with="$(file --mime-encoding --brief "${f}")"
    without="$(file --magic-file /dev/null --mime-encoding --brief "${f}")"
    with_binary=no; without_binary=no
    [ "${with}" = binary ] && with_binary=yes
    [ "${without}" = binary ] && without_binary=yes
    if [ "${with_binary}" != "${without_binary}" ]; then
      verdicts="DIFFER on ${f}"
    fi
  done
fi

printf '%-14s %-22s long=%-4s short=%-4s %s\n' \
  "${os}" "${version}" "${long_flag}" "${short_flag}" "${verdicts}"

cd /
rm --recursive --force "${DIR}"

[ "${long_flag}" = yes ] && [ "${verdicts}" = match ]
