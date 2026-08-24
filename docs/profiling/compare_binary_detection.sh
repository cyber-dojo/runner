#!/usr/bin/env bash
# Check whether a NUL-byte test can replace `file --mime-encoding` in the
# runner's exit trap, and whether the grep flags such a test needs even exist.
#
# It cannot, on two counts, which is why this probe is kept: to stop the idea
# being re-proposed.
#
#   1. `grep -P` is absent from the Alpine images, and a literal NUL cannot be
#      passed as a pattern argument, so there is no portable NUL search.
#   2. `file --mime-encoding` reports a UTF-16 file as utf-16le, which is not
#      the string "binary", so the exit trap keeps it. Any NUL-based test calls
#      it binary and would delete it, silently discarding UTF-16 files from
#      katas.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/probe_lib.sh"

probe_help_check "${1:-}" "Usage: compare_binary_detection.sh

Builds a set of files spanning the interesting encodings and reports where
\`file --mime-encoding\` and a NUL-byte test disagree. Run inside a language
image:

  docker run --rm --entrypoint=\"\" --volume \$PWD:/probe:ro \\
    ghcr.io/cyber-dojo-languages/csharp_nunit:70e19ed \\
    bash /probe/compare_binary_detection.sh"

readonly DIR=/tmp/probe_binary_detection

rm --recursive --force "${DIR}"
mkdir --parents "${DIR}"
cd "${DIR}"

printf 'hello world\n'      > ascii.txt
printf 'caf\xc3\xa9 utf8\n' > utf8.txt
printf 'caf\xe9 latin1\n'   > latin1.txt   # invalid UTF-8, contains no NUL
printf 'a\x00b\n'           > has_nul.txt
printf '\xff\xfeA\x00B\x00' > utf16.txt    # UTF-16 BOM, contains NULs
cp "$(command -v ls)" elf.bin

probe_environment
# Both flags are probed because a NUL search needs one of them, and their
# availability differs between the Debian and Alpine based language images.
echo "grep -P supported: $(echo x | grep -qP 'x' 2>/dev/null && echo yes || echo no)"
echo "grep -I supported: $(echo x | grep -qI 'x' 2>/dev/null && echo yes || echo no)"
echo

# True when the file contains at least one NUL byte, which is what every cheap
# binary test ultimately keys on.
has_nul_byte()
{
  local -r filename="${1}"
  ! tr --delete '\000' < "${filename}" | cmp --silent - "${filename}"
}

printf '%-12s %-22s %-8s %s\n' FILE 'file --mime-encoding' HAS_NUL 'AGREE?'
for f in *; do
  encoding="$(file --mime-encoding --brief "${f}")"
  if has_nul_byte "${f}"; then nul=yes; else nul=no; fi
  if { [ "${encoding}" = binary ] && [ "${nul}" = yes ]; } ||
     { [ "${encoding}" != binary ] && [ "${nul}" = no ]; }; then
    agree=yes
  else
    agree='NO <-- differs'
  fi
  printf '%-12s %-22s %-8s %s\n' "${f}" "${encoding}" "${nul}" "${agree}"
done

cd /
rm --recursive --force "${DIR}"
