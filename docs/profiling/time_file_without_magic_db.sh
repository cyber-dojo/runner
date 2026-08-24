#!/usr/bin/env bash
# Measure how much of `file --mime-encoding` is its magic database.
#
# The 7.6 ms per-file cost on the Alpine images, measured by
# time_trap_spawns.sh, is attributable to the 10.3 MB magic database that
# file(1) loads on every invocation. time_file_batching.sh tests only batching,
# which amortises that load rather than avoiding it. Encoding detection is a byte-classification pass over the file, so
# it need not consult the database at all, and `--magic-file /dev/null` asks for
# that. Batching and suppression attack the same cost by different means, so both
# are measured here, separately and together.
#
# Whether the faster answer is also the same answer is a separate question, asked
# over a wider corpus by compare_magic_db_verdicts.sh.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/probe_lib.sh"

probe_help_check "${1:-}" "Usage: time_file_without_magic_db.sh

Times \`file --mime-encoding\` with and without its magic database, per-file and
batched. Run inside a language image:

  docker run --rm --entrypoint=\"\" --volume \$PWD:/probe:ro \\
    ghcr.io/cyber-dojo-languages/csharp_nunit:70e19ed \\
    bash /probe/time_file_without_magic_db.sh"

readonly RUNS=100
readonly BATCH_FILES=200
readonly DIR=/tmp/probe_file_without_magic_db

rm --recursive --force "${DIR}"
mkdir --parents "${DIR}"
cd "${DIR}"

probe_environment
echo "file version: $(file --version | head -1)"
# The size the finding blames for the cost, so the claim can be re-checked here
# rather than taken on trust.
echo "magic db: $(ls -l /usr/share/misc/magic.mgc 2>/dev/null || echo 'not at /usr/share/misc/magic.mgc')"
echo

# Reports the encoding file(1) gives, with the magic database suppressed. A
# failure here (rather than a differing verdict) means the flag is unusable.
encoding_without_magic_db()
{
  local -r filename="${1}"
  file --magic-file /dev/null --mime-encoding --brief "${filename}"
}


# Both targets are timed because file(1)'s cost depends on what it is reading,
# not just on its startup. A binary is decided by the first NUL it meets, whereas
# a text file is only classified once the whole of it has been scanned and no
# encoding has been ruled in early, so text is the slower input and the one the
# sandbox is full of. time_trap_spawns.sh times the two-byte case, so timing it
# here too is what makes the two probes comparable.
printf 'xx' > two_bytes.txt
cp "$(command -v ls)" elf.bin

echo "--- per-file timings, mean of ${RUNS} ---"
probe_preflight file --mime-encoding two_bytes.txt
probe_preflight encoding_without_magic_db two_bytes.txt
probe_timeit 'bash -c true (spawn floor)'      "${RUNS}" bash -c true
probe_timeit 'file, 2-byte text'               "${RUNS}" file --mime-encoding two_bytes.txt
probe_timeit 'file, 2-byte text, no magic db'  "${RUNS}" encoding_without_magic_db two_bytes.txt
probe_timeit 'file, ELF binary'                "${RUNS}" file --mime-encoding elf.bin
probe_timeit 'file, ELF binary, no magic db'   "${RUNS}" encoding_without_magic_db elf.bin
echo

# Batching and suppressing the database attack the same cost by different means,
# so the interesting number is what remains when both are applied.
mkdir --parents batch
for (( i = 0; i < BATCH_FILES; i++ )); do
  printf 'int main() { return 0; }\n' > "batch/file_${i}.c"
done

batched_with_magic_db()
{
  find batch -type f -print0 | xargs -0 file --mime-encoding
}

batched_without_magic_db()
{
  find batch -type f -print0 | xargs -0 file --magic-file /dev/null --mime-encoding
}

echo "--- batched over ${BATCH_FILES} files, mean of 10 ---"
probe_preflight batched_with_magic_db
probe_preflight batched_without_magic_db
probe_timeit_ms 'batched, with magic db'    10 batched_with_magic_db
probe_timeit_ms 'batched, no magic db'      10 batched_without_magic_db

cd /
rm --recursive --force "${DIR}"
