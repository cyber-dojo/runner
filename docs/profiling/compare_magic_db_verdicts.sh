#!/usr/bin/env bash
# Check whether suppressing file(1)'s magic database changes any verdict that
# is_binary_file acts on.
#
# time_file_without_magic_db.sh shows `--magic-file /dev/null` making
# `--mime-encoding` 31x faster on a text file, because the 10.3 MB database is
# the whole cost. That is only usable if it decides the same files are binary,
# which is the bar that rejected the NUL-byte test in compare_binary_detection.sh.
#
# The corpus is built around where the two can disagree. A binary format whose
# header contains a NUL is called binary by either route, so it is uninteresting.
# The risk is a format the database recognises but whose bytes are all valid text:
# PDF, PostScript and GIF have NUL-free ASCII signatures, so the database can
# call them binary where a bare encoding scan calls them us-ascii, and the runner
# would then keep a file it currently deletes.
#
# Only the binary/non-binary boundary matters, not the encoding name, because
# is_binary_file tests for the single string "binary". A differing name that
# stays on the same side of that boundary changes nothing, so this probe fails
# only on a crossing.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/probe_lib.sh"

probe_help_check "${1:-}" "Usage: compare_magic_db_verdicts.sh

Compares \`file --mime-encoding\` with and without its magic database over real
and synthesised sandbox artifacts. Exits non-zero if any file changes side of the
binary/non-binary boundary. Run inside a language image:

  docker run --rm --entrypoint=\"\" --volume \$PWD:/probe:ro \\
    ghcr.io/cyber-dojo-languages/csharp_nunit:70e19ed \\
    bash /probe/compare_magic_db_verdicts.sh"

readonly DIR=/tmp/probe_magic_db_verdicts

rm --recursive --force "${DIR}"
mkdir --parents "${DIR}"
cd "${DIR}"

# Encodings, including the utf-16le case that rejected the NUL-byte test.
printf 'hello world\n'      > ascii.txt
printf 'caf\xc3\xa9 utf8\n' > utf8.txt
printf 'caf\xe9 latin1\n'   > latin1.txt
printf '\xff\xfeA\x00B\x00' > utf16.txt
printf '\x81\x82\x83\x84'   > high_bytes.bin   # no NUL, no valid encoding

# The size<2 cases that comment [2] in home_files.rb exists for, which says the
# database misreports tiny text files as binary. If that misreport is itself a
# database artifact then the guard is unnecessary without it.
printf ''                   > empty.txt
printf 'x'                  > one_byte.txt
printf 'xx'                 > two_bytes.txt

# Real artifacts, the kind a test run actually leaves in a sandbox.
cp "$(command -v ls)" elf_exe.bin
so="$(find /usr/lib -name '*.so*' -type f 2>/dev/null | head -1 || true)"
if [ -n "${so}" ]; then cp "${so}" elf_shared.so; fi
printf 'compiled output\n' > to_compress.txt
gzip --stdout to_compress.txt > artifact.gz
tar --create --file artifact.tar to_compress.txt
rm --force to_compress.txt

# Binary formats with NUL bytes in their headers, decided the same way by either
# route, present as controls.
printf '\xca\xfe\xba\xbe\x00\x00\x00\x34' > java.class
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\x0d' > image.png
printf 'MZ\x90\x00\x03\x00\x00\x00'      > dos.exe

# The risk cases: signatures the database knows, with no NUL and no byte outside
# ASCII anywhere in the file.
printf '%%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>\n%%%%EOF\n' > ascii_only.pdf
printf '%%!PS-Adobe-3.0\n/Helvetica findfont\nshowpage\n' > ascii_only.ps
printf 'GIF89a plain ascii payload\n' > ascii_only.gif

probe_environment
echo "file version: $(file --version | head -1)"
echo

# True when file(1) calls the file binary, which is the only thing the runner's
# is_binary_file acts on.
is_binary_verdict()
{
  [ "${1}" = binary ]
}

printf '%-16s %-14s %-14s %s\n' FILE WITH_MAGIC_DB WITHOUT BOUNDARY
crossings=0
for f in *; do
  with="$(file --mime-encoding --brief "${f}")"
  without="$(file --magic-file /dev/null --mime-encoding --brief "${f}" 2>&1 || echo FAILED)"
  if is_binary_verdict "${with}"; then with_side=binary; else with_side=text; fi
  if is_binary_verdict "${without}"; then without_side=binary; else without_side=text; fi
  if [ "${with_side}" = "${without_side}" ]; then
    boundary=same
  else
    boundary="CROSSED ${with_side}->${without_side}"
    crossings=$((crossings + 1))
  fi
  printf '%-16s %-14s %-14s %s\n' "${f}" "${with}" "${without}" "${boundary}"
done

echo
cd /
rm --recursive --force "${DIR}"

if [ "${crossings}" -ne 0 ]; then
  echo "${crossings} file(s) changed side of the binary boundary." >&2
  echo 'Suppressing the magic database would change which files the runner deletes.' >&2
  exit 1
fi
echo 'No file changed side of the binary boundary.'
