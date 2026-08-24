#!/usr/bin/env bash
# Check whether the output of ONE batched `file` call can be parsed back into
# filenames safely, which is what the batching rewrite of the exit trap depends on.
#
# The per-file version in home_files.rb never parses anything: it asks about one
# known filename and greps for a verdict. Batching inverts that, so the output has
# to be split back into (filename, encoding) pairs, and the default `name: verdict`
# format is ambiguous the moment a filename contains ": " or a newline. A sandbox
# filename comes from a kata, so it is attacker-influenced and cannot be assumed
# tame.
#
# Also checks the find predicates the rewrite uses to drop `stat` from the walk,
# because busybox find is what the Alpine images ship and its -size handling is
# the part most likely to differ.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/probe_lib.sh"

probe_help_check "${1:-}" "Usage: check_batched_file_output_parsing.sh

Reports whether file --print0 gives an unambiguous separator, and whether the
find -size predicates behave. Run inside a language image:

  docker run --rm --entrypoint=\"\" --volume \$PWD:/probe:ro \\
    ghcr.io/cyber-dojo-languages/csharp_nunit:70e19ed \\
    bash /probe/check_batched_file_output_parsing.sh"

readonly DIR=/tmp/probe_batched_file_output

rm --recursive --force "${DIR}"
mkdir --parents "${DIR}"
cd "${DIR}"

# Filenames chosen to break naive parsing. The colon-space one mimics the exact
# separator file uses, so a split on ": " cannot tell filename from verdict.
printf 'hello\n'  > 'plain.txt'
printf 'hello\n'  > 'awkward: binary.txt'
printf 'hello\n'  > 'has:colon.txt'
cp "$(command -v ls)" 'an elf.bin'

probe_environment
echo "file version: $(file --version 2>&1 | head -1)"
echo "awk: $(command -v awk || echo MISSING)"
echo "find: $(command -v find)"
echo

echo '--- default output format ---'
find . -type f -print0 | xargs -0 file --magic-file /dev/null --mime-encoding
echo

echo '--- with --print0, separator shown as text ---'
# tr turns the NUL into a visible marker so the layout can be read here. The
# question is where the NUL lands relative to the ":" separator, because that is
# what decides whether a filename can be recovered unambiguously.
find . -type f -print0 \
  | xargs -0 file --print0 --magic-file /dev/null --mime-encoding \
  | tr '\000' '@'
echo
echo

echo '--- does --print0 survive in this build? ---'
if find . -type f -print0 | xargs -0 file --print0 --magic-file /dev/null \
     --mime-encoding  > /dev/null 2>&1; then
  echo 'file --print0: accepted'
else
  echo 'file --print0: REJECTED'
fi
echo

echo '--- find -size predicates ---'
# The rewrite uses -size +1c to subsume the "size < 2 is text" guard and
# -size +Nc to select oversized files, so both need to mean what they say.
printf ''     > empty.txt
printf 'x'    > one_byte.txt
printf 'xx'   > two_bytes.txt
echo "files over 1c (expect two_bytes.txt and the larger ones, not empty/one_byte):"
find . -type f -size +1c | sort
echo
echo "files over 100c (expect only the elf):"
find . -type f -size +100c | sort

cd /
rm --recursive --force "${DIR}"
