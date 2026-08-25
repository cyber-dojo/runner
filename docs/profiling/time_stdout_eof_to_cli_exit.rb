# frozen_string_literal: true

# Measures what waiting for the docker CLI costs after the payload has arrived.
#
# capture3_with_timeout.rb reads the container's stdout in a thread but returns
# on waiter.value, the docker CLI process exiting. The payload is complete
# earlier than that, at stdout EOF: the container's main process has finished
# writing and closed the pipe. Everything between those two instants is the
# learner waiting for bookkeeping.
#
# This probe reproduces that spawn exactly and times both instants, with and
# without --rm, so the gap can be read off directly. Interleaved, because a
# laptop's docker daemon drifts and running all of one variant and then all of
# the other would attribute that drift to the change.
#
# Run on the host:
#
#   ruby docs/profiling/time_stdout_eof_to_cli_exit.rb
#
# Not inside the runner image on a developer machine whose architecture differs
# from it. The gap being measured is the docker CLI's own exit, and emulating
# that process inflates it.

IMAGE = ARGV[0] || 'ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd'
RUNS = 10
PAYLOAD_KB = 64

# Mirrors the flags runner.rb uses. --init is there because it makes removal
# faster, and the tmpfs mounts are part of what has to be torn down.
FLAGS = '--init --tmpfs /sandbox:exec,size=250M --tmpfs /tmp:exec,size=250M,mode=1777'
EMIT = "dd if=/dev/zero bs=1024 count=#{PAYLOAD_KB} status=none | gzip -1"

# Returns monotonic seconds.
def now
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

# Returns the docker run command for one container, with or without --rm.
def command_for(name, rm)
  [
    'docker run',
    (rm ? '--rm' : nil),
    FLAGS,
    "--name #{name}",
    "--entrypoint=''",
    IMAGE,
    %(bash -c "#{EMIT}")
  ].compact.join(' ')
end

# Runs one container and returns [seconds to stdout EOF, seconds from EOF to
# the CLI exiting], spawning it the way capture3_with_timeout.rb does.
def time_one(name, rm)
  reader, writer = IO.pipe
  reader.binmode
  t0 = now
  pid = Process.spawn(command_for(name, rm), pgroup: true, out: writer, err: File::NULL)
  waiter = Process.detach(pid)
  writer.close
  reader.read
  t_eof = now
  waiter.value
  t_exit = now
  reader.close
  [t_eof - t0, t_exit - t_eof]
end

# Returns the mean of an array of seconds, in microseconds.
def mean_micros(values)
  ((values.sum / values.size) * 1_000_000).round
end

# Prints one labelled row.
def print_row(label, to_eof, eof_to_exit)
  puts(format('%-30s %10s us %14s us', label, to_eof, eof_to_exit))
end

rm_eof = []
rm_gap = []
keep_eof = []
keep_gap = []

RUNS.times do |i|
  eof, gap = time_one("probe_eof_#{i}_#{Process.pid}_rm", true)
  rm_eof << eof
  rm_gap << gap

  name = "probe_eof_#{i}_#{Process.pid}_keep"
  eof, gap = time_one(name, false)
  keep_eof << eof
  keep_gap << gap
  system("docker rm #{name}", out: File::NULL, err: File::NULL)
end

puts "image: #{IMAGE}"
puts(format('%-30s %13s %17s', '', 'spawn to EOF', 'EOF to CLI exit'))
print_row('docker run --rm', mean_micros(rm_eof), mean_micros(rm_gap))
print_row('docker run, no --rm', mean_micros(keep_eof), mean_micros(keep_gap))
