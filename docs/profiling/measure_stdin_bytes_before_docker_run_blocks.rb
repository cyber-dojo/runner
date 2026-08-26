# frozen_string_literal: true

# Measures how many bytes go into [docker run]'s stdin before the write stalls.
#
# capture3_with_timeout.rb writes the incoming tgz to the CLI's stdin on the
# same thread that then waits for the run. A write that blocks there blocks
# before any deadline is armed, so whether it can block at all decides whether
# that write needs bounding.
#
# Three rows, because the CLI's own buffering is the unknown:
#
#   bare pipe, nobody reading   the OS pipe buffer, and nothing else
#   docker run, never reads     container runs sleep, so only the pipe plus
#                               whatever the CLI holds absorbs the write
#   docker run, drains stdin    container runs cat, which is the shape of the
#                               real body, whose first act is [tar -zxf -]
#
# A stall is a write that stays unwritable for STALL_SECONDS. The draining row
# stops at MAX_BYTES instead, which counts as not stalling.
#
# Run on the host:
#
#   ruby docs/profiling/measure_stdin_bytes_before_docker_run_blocks.rb

IMAGE = ARGV[0] || 'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a'
CHUNK_BYTES = 64 * 1024
MAX_BYTES = 64 * 1024 * 1024
STALL_SECONDS = 2

UID = 41_966
GID = 51_966

# Returns the docker run command runner.rb builds, for the named container.
def docker_run_command(name, body)
  [
    'docker run --rm --init --interactive',
    "--user=#{UID}:#{GID}",
    "--tmpfs /sandbox:exec,size=250M,uid=#{UID},gid=#{GID}",
    '--tmpfs /tmp:exec,size=250M,mode=1777',
    '--memory=2g --net=none --pids-limit=128',
    "--name #{name}",
    "--entrypoint=''",
    IMAGE,
    %(bash -c "#{body}")
  ].join(' ')
end

# Writes until the pipe stays unwritable for STALL_SECONDS, or MAX_BYTES have
# gone in. Returns [bytes, stalled].
def fill(pipe)
  chunk = 'x' * CHUNK_BYTES
  total = 0
  while total < MAX_BYTES
    written = pipe.write_nonblock(chunk, exception: false)
    if written == :wait_writable
      return [total, true] if IO.select(nil, [pipe], nil, STALL_SECONDS).nil?
    else
      total += written
    end
  end
  [total, false]
end

# The OS pipe buffer on its own, with the read end open and never read.
def fill_bare_pipe
  read_end, write_end = IO.pipe
  write_end.binmode
  bytes, stalled = fill(write_end)
  write_end.close
  read_end.close
  [bytes, stalled]
end

# Fills the stdin of a docker run whose container behaves as body says.
def fill_docker_run_stdin(name, body)
  in_read, in_write = IO.pipe
  in_write.binmode
  pid = Process.spawn(docker_run_command(name, body), in: in_read, out: File::NULL, err: File::NULL)
  waiter = Process.detach(pid)
  in_read.close

  bytes, stalled = fill(in_write)

  system("docker stop --time 1 #{name}", out: File::NULL, err: File::NULL)
  in_write.close unless in_write.closed?
  waiter.value
  [bytes, stalled]
end

# Prints one row, in whole KB.
def print_row(label, result)
  bytes, stalled = result
  verdict = stalled ? "stalled after #{STALL_SECONDS}s" : 'no stall'
  puts(format('%-34s %12d %s', label, bytes / 1024, verdict))
end

puts "image: #{IMAGE}"
puts(format('%-34s %12s %s', 'stdin filled', 'KB accepted', 'outcome'))
print_row('bare pipe, nobody reading', fill_bare_pipe)
print_row('docker run, never reads stdin',
          fill_docker_run_stdin("probe_stdin_deaf_#{Process.pid}", 'sleep 30'))
print_row('docker run, drains stdin',
          fill_docker_run_stdin("probe_stdin_cat_#{Process.pid}", 'cat >/dev/null'))
