#!/usr/bin/env bash
# Compare N separate `file` invocations against one batched invocation.
#
# The runner's exit trap calls `file --mime-encoding` once per sandbox file. The
# cost of each call is dominated by the magic database `file` loads at startup,
# so batching amortises it. This probe prices that.
#
# It measured 44x on an Alpine image (1507ms for 200 files against 34ms) and 22x
# on a Debian one, with identical verdicts, which is why batching is the
# recommended fix rather than substituting a cheaper test. See
# cyber-dojo/faster-traffic-light.md, finding 1.
set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/probe_lib.sh"

probe_help_check "${1:-}" "Usage: time_file_batching.sh [file-count]

Defaults to 200 files. Run inside a language image:

  docker run --rm --entrypoint=\"\" --volume \$PWD:/probe:ro \\
    ghcr.io/cyber-dojo-languages/csharp_nunit:70e19ed \\
    bash /probe/time_file_batching.sh"

readonly N="${1:-200}"
readonly DIR=/tmp/probe_file_batching

rm --recursive --force "${DIR}"
mkdir --parents "${DIR}"
for (( i = 0; i < N; i++ )); do
  printf 'xx' > "${DIR}/f${i}.txt"
done

probe_environment
echo "files: ${N}"
echo

# Times the whole loop once, not per iteration, so probe_timeit is called with
# a single run over a function that does all N invocations.
per_file_pass()
{
  local f
  for f in "${DIR}"/*; do
    file --mime-encoding "${f}" > /dev/null
  done
}

batched_pass()
{
  # -0 rather than --null: the Alpine language images ship busybox xargs, which
  # implements only the short form. This is the one place in these probes where
  # the long-flag convention cannot hold.
  find "${DIR}" -type f -print0 | xargs -0 file --mime-encoding > /dev/null
}

probe_preflight per_file_pass
probe_preflight batched_pass

probe_timeit_ms "${N} separate invocations" 1 per_file_pass
probe_timeit_ms '1 batched invocation'      1 batched_pass

rm --recursive --force "${DIR}"
