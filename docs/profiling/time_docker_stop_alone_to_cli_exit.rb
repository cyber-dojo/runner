# frozen_string_literal: true

# Measures how soon [docker run] exits once [docker stop] has been issued.
#
# capture3_with_timeout.rb ends a timed-out press by stopping the container and
# nothing else: the container's stdout closes, so the CLI exits and the
# runner's read completes. This probe is what that rests on, and it also prices
# the alternative of signalling the CLI first.
#
# Two ways of ending a timed-out press:
#
#   stop only  no signals at all: docker stop --time 1, then wait for the CLI
#   kill+stop  TERM then KILL to the CLI's process group, and a docker stop
#              besides, because killing the CLI does not stop the container
#
# Both are run against two katas, because one hung process is the easy case and
# is not what the timeout path exists for:
#
#   sleep      one process that ignores the clock
#   fork bomb  the shell fork bomb from test/client/robustness_test.rb 1B5CD6,
#              which saturates --pids-limit, so the stop has many processes to
#              end and send_tgz cannot fork the find, file, tar and gzip its
#              EXIT trap needs
#
# The press is the real one: the payload carries cyber_dojo_main.sh from
# home_files.rb next to the kata, and the container runs it, so the EXIT trap
# and the pids-limit interact as they do in production. A cyber-dojo.sh that
# merely backgrounds work is not enough on its own; that returns at once and
# the container exits without ever timing out.
#
# For the stop-only rows the two intervals inside the overshoot are split out:
# how long the stop itself takes, which says whether the container went on the
# SIGTERM or had to wait for the SIGKILL a second later, and how long the CLI
# takes to exit once the stop has been issued, which is the claim under test.
#
# Run on the host:
#
#   ruby docs/profiling/time_docker_stop_alone_to_cli_exit.rb
#
# Not inside the runner image on a developer machine whose architecture differs
# from it, since a docker CLI spawn is part of what is being measured.

require 'timeout'
require_relative '../../source/server/home_files'
require_relative '../../source/server/sandbox'
require_relative '../../source/server/tgz'

extend HomeFiles

IMAGE = ARGV[0] || 'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a'
RUNS = 3
MAX_SECONDS = 2
MAX_FILE_SIZE = 50 * 1024

UID = 41_966
GID = 51_966

# What runner.rb runs in the container.
BODY = 'tar -C / -zxf - && bash ~/cyber_dojo_main.sh'

SLEEP_KATA = "sleep 30\n"

# test/client/robustness_test.rb 1B5CD6.
FORK_BOMB_KATA = <<~SHELL
  bomb()
  {
    echo "bomb"
    bomb | bomb &
  }
  bomb
SHELL

KATAS = [
  ['sleep', SLEEP_KATA],
  ['fork bomb', FORK_BOMB_KATA]
].freeze

# Returns monotonic seconds.
def now
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

# Returns the tgz runner.rb sends in: the kata's files under the sandbox dir,
# plus the main script that runs them and installs the send_tgz EXIT trap.
def payload(kata)
  files = Sandbox.in({ 'cyber-dojo.sh' => kata })
  TGZ.of(files.merge(home_files(Sandbox::DIR, MAX_FILE_SIZE)))
end

# Returns the docker run command runner.rb builds, for the named container.
def docker_run_command(name)
  [
    'docker run --rm --init --interactive',
    "--user=#{UID}:#{GID}",
    "--tmpfs #{Sandbox::DIR}:exec,size=250M,uid=#{UID},gid=#{GID}",
    '--tmpfs /tmp:exec,size=250M,mode=1777',
    '--memory=2g --net=none --pids-limit=128',
    "--name #{name}",
    "--entrypoint=''",
    IMAGE,
    %(bash -c "#{BODY}")
  ].join(' ')
end

# Starts the press and returns the pieces needed to wait it out: the waiter
# thread for the CLI process, its pid, a thread reading stdout to EOF, the read
# end of that pipe, and the monotonic instant the press began.
def start_press(name, kata, pgroup:)
  in_read, in_write = IO.pipe
  out_read, out_write = IO.pipe
  in_write.binmode
  out_read.binmode

  t0 = now
  reader = Thread.new { out_read.read }
  pid = Process.spawn(docker_run_command(name), pgroup: pgroup, in: in_read, out: out_write, err: File::NULL)
  waiter = Process.detach(pid)
  in_read.close
  out_write.close
  in_write.write(payload(kata))
  in_write.close

  [waiter, pid, reader, out_read, t0]
end

# Runs docker stop and returns how long it took, which is the container's own
# shutdown: under a second means it went on the SIGTERM.
def docker_stop(name)
  t0 = now
  system("docker stop --time 1 #{name}", out: File::NULL, err: File::NULL)
  now - t0
end

# Times a timed-out press ended by docker stop alone, with no signals sent to
# the CLI at all. The stop runs on a thread so that the interval being measured
# is the CLI's exit against the instant the stop was issued, rather than against
# the stop returning.
def timeout_via_stop_only(name, kata)
  waiter, _pid, reader, out_read, t0 = start_press(name, kata, pgroup: false)

  waiter.join(MAX_SECONDS)
  t_stop = now
  stop_seconds = nil
  stopper = Thread.new { stop_seconds = docker_stop(name) }

  waiter.value
  stdout = reader.value
  t_exit = now
  stopper.join
  out_read.close

  { total: t_exit - t0, stop_to_exit: t_exit - t_stop, stop: stop_seconds,
    bytes: stdout.to_s.bytesize, name: name }
end

# Times a timed-out press ended by signalling the CLI first: Timeout.timeout
# around the wait, TERM to the process group, KILL if the join fails, and a
# docker stop besides, because killing the CLI leaves the container running.
def timeout_via_kill_and_stop(name, kata)
  waiter, pid, reader, out_read, t0 = start_press(name, kata, pgroup: true)

  begin
    Timeout.timeout(MAX_SECONDS) { waiter.value }
  rescue Timeout::Error
    Process.kill(:TERM, -pid)
    Process.kill(:KILL, -pid) unless waiter.join(1)
    Thread.new { docker_stop(name) }
  end
  stdout = reader.value
  total = now - t0
  out_read.close

  { total: total, stop_to_exit: nil, stop: nil,
    bytes: stdout.to_s.bytesize, name: name }
end

# Returns the names of any of this probe's containers still known to docker,
# after giving the daemon a moment to finish disposing of them.
def survivors(names)
  sleep 3
  listed = `docker ps --all --format '{{.Names}}'`.split("\n")
  names & listed
end

# Returns the mean of an array of seconds, in milliseconds, to one decimal, or
# a dash when the measurement does not apply to that row.
def mean_millis(values)
  return '-' if values.compact.empty?

  format('%.1f', (values.sum / values.size) * 1000)
end

# Returns the mean number of payload bytes read back, in bytes.
def mean_bytes(values)
  format('%d', values.sum / values.size)
end

# Prints one row: the overshoot past max_seconds is what the learner feels.
def print_row(label, results)
  totals = results.map { |r| r[:total] }
  puts(format('%-32s %9s %13s %13s %9s %10s',
              label,
              mean_millis(totals),
              mean_millis(totals.map { |s| s - MAX_SECONDS }),
              mean_millis(results.map { |r| r[:stop_to_exit] }),
              mean_millis(results.map { |r| r[:stop] }),
              mean_bytes(results.map { |r| r[:bytes] })))
end

rows = []
names = []

KATAS.each_with_index do |(kata_name, kata), k|
  kills = []
  stops = []
  RUNS.times do |i|
    kills << timeout_via_kill_and_stop("probe_sa_kill_#{k}_#{i}_#{Process.pid}", kata)
    stops << timeout_via_stop_only("probe_sa_stop_#{k}_#{i}_#{Process.pid}", kata)
  end
  rows << ["#{kata_name}: kill group, then stop", kills]
  rows << ["#{kata_name}: stop only, no signals", stops]
  names.concat((kills + stops).map { |r| r[:name] })
end

puts "image: #{IMAGE}"
puts "max_seconds: #{MAX_SECONDS}"
puts(format('%-32s %9s %13s %13s %9s %10s',
            'timed-out press', 'total ms', 'overshoot ms', 'stop to exit', 'stop ms', 'payload B'))
rows.each { |label, results| print_row(label, results) }

left = survivors(names)
puts
puts(left.empty? ? 'containers left behind: none' : "containers left behind: #{left.inspect}")
