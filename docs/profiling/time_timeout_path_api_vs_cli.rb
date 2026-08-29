# frozen_string_literal: true

# Measures what a timed-out test-run costs beyond max_seconds, and whether the
# container is actually gone afterwards.
#
# A learner whose cyber-dojo.sh loops forever should wait max_seconds and then
# see a timed_out light. Anything past that is overshoot, and it is invisible
# in the happy-path probes because none of them time out.
#
# Three ways of doing it:
#
#   cli      what runner.rb does now: Timeout.timeout around waiting for the
#            docker CLI, then kill the process group, then a separate
#            docker stop because killing the CLI does not kill the container
#   api      a read deadline on the attach socket, then stop the container
#            over the socket before answering
#   api+thread  the same, answering as soon as the deadline fires and stopping
#            the container on a thread
#
# The container's disposal is checked rather than assumed: with AutoRemove the
# daemon should remove it once it exits, however it was stopped.
#
# Run on the host:
#
#   ruby docs/profiling/time_timeout_path_api_vs_cli.rb
#
# Not inside the runner image on a developer machine whose architecture differs
# from it, since a docker CLI spawn is part of what is being compared.

require 'json'
require 'socket'
require 'timeout'
require_relative '../../source/server/lib/tgz'

IMAGE = ARGV[0] || 'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a'
RUNS = 3
MAX_SECONDS = 2
SOCKET_PATH = '/var/run/docker.sock'

UID = 41_966
GID = 51_966

# Reads the files off stdin and then never finishes, which is the shape of a
# kata whose tests hang.
BODY = 'tar -C /tmp -zxf - && sleep 30'

PAYLOAD_IN = TGZ.of({ 'tmp/cyber-dojo.sh' => "sleep 30\n" })

# Returns monotonic seconds.
def now
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

# Returns a socket connected to the daemon.
def daemon_socket
  UNIXSocket.new(SOCKET_PATH)
end

# Reads one HTTP response's headers, returning its status code.
def read_headers(socket)
  code = socket.gets.to_s.split(' ')[1].to_i
  while (line = socket.gets)
    break if line == "\r\n" || line == "\n"
  end
  code
end

# Sends one request on its own connection and returns [code, body].
def request(method, path, body = nil)
  socket = daemon_socket
  payload = body.nil? ? nil : JSON.generate(body)
  lines = ["#{method} #{path} HTTP/1.1", 'Host: docker', 'Connection: close']
  unless payload.nil?
    lines << 'Content-Type: application/json'
    lines << "Content-Length: #{payload.bytesize}"
  end
  socket.write("#{lines.join("\r\n")}\r\n\r\n")
  socket.write(payload) unless payload.nil?
  code = read_headers(socket)
  rest = socket.read
  socket.close
  [code, rest]
end

# The container config the CLI would build from runner.rb's flags.
def create_body
  {
    'Image' => IMAGE,
    'Cmd' => ['bash', '-c', BODY],
    'Entrypoint' => [],
    'User' => "#{UID}:#{GID}",
    'OpenStdin' => true,
    'StdinOnce' => true,
    'AttachStdin' => true,
    'AttachStdout' => true,
    'AttachStderr' => true,
    'Tty' => false,
    'HostConfig' => {
      'AutoRemove' => true,
      'Init' => true,
      'Memory' => 2 * 1024 * 1024 * 1024,
      'NetworkMode' => 'none',
      'PidsLimit' => 128,
      'Tmpfs' => {
        '/sandbox' => "exec,size=250M,uid=#{UID},gid=#{GID}",
        '/tmp' => 'exec,size=250M,mode=1777'
      }
    }
  }
end

# Opens the hijacked attach stream.
def attach(id)
  socket = daemon_socket
  path = "/containers/#{id}/attach?stream=1&stdin=1&stdout=1&stderr=1"
  socket.write(
    "POST #{path} HTTP/1.1\r\nHost: docker\r\nContent-Length: 0\r\n" \
    "Upgrade: tcp\r\nConnection: Upgrade\r\n\r\n"
  )
  read_headers(socket)
  socket
end

# Raised when the deadline passes with the container still running.
class DeadlineReached < RuntimeError
end

# Reads exactly n bytes, or raises DeadlineReached, or returns nil at end of
# stream. The deadline is absolute and reapplied before every wait, because it
# bounds the whole test-run rather than one read: a container dribbling output
# would never trip a per-read timeout.
#
# Production would write this with IO#timeout=, which ruby 3.4 has and which
# raises IO::TimeoutError by itself. IO.select is used here so this probe runs
# on the host, whose ruby is older, and the host is where it must run for the
# docker CLI it spawns to be unemulated.
def read_exactly(socket, size, deadline)
  buffer = +''
  while buffer.bytesize < size
    remaining = deadline - now
    raise DeadlineReached if remaining <= 0
    raise DeadlineReached if IO.select([socket], nil, nil, remaining).nil?

    chunk = socket.read_nonblock(size - buffer.bytesize, exception: false)
    return nil if chunk.nil?

    buffer << chunk unless chunk == :wait_readable
  end
  buffer
end

# Reads attach frames until the container finishes or the deadline passes.
def read_frames_until(socket, deadline)
  loop do
    header = read_exactly(socket, 8, deadline)
    break if header.nil?

    _stream, size = header.unpack('C x3 N')
    break if size.positive? && read_exactly(socket, size, deadline).nil?
  end
end

# Times a timed-out test-run over the socket. When threaded_stop is true the
# answer is given the moment the deadline fires and the container is stopped
# behind it, which is what a runner would do.
def timeout_via_api(name, threaded_stop:)
  _code, body = request('POST', "/containers/create?name=#{name}", create_body)
  id = JSON.parse(body[/\{.*\}/m])['Id']
  stream = attach(id)
  request('POST', "/containers/#{id}/start")

  t0 = now
  stream.write(PAYLOAD_IN)
  stream.close_write
  begin
    read_frames_until(stream, t0 + MAX_SECONDS)
  rescue DeadlineReached
    stopper = -> { request('POST', "/containers/#{id}/stop?t=1") }
    if threaded_stop
      Thread.new(&stopper)
    else
      stopper.call
    end
  end
  seconds = now - t0
  stream.close
  [seconds, name]
end

# Times a timed-out test-run through the CLI, reproducing
# capture3_with_timeout.rb:
# Timeout.timeout around the wait, then TERM to the process group, then KILL if
# the join fails, and a docker stop besides, because killing the CLI leaves the
# container running.
def timeout_via_cli(name)
  command = [
    'docker run --rm --init --interactive',
    "--user=#{UID}:#{GID}",
    "--tmpfs /sandbox:exec,size=250M,uid=#{UID},gid=#{GID}",
    '--tmpfs /tmp:exec,size=250M,mode=1777',
    '--memory=2g --net=none --pids-limit=128',
    "--name #{name}",
    "--entrypoint=''",
    IMAGE,
    %(bash -c "#{BODY}")
  ].join(' ')

  in_read, in_write = IO.pipe
  out_read, out_write = IO.pipe
  in_write.binmode
  out_read.binmode

  t0 = now
  reader = Thread.new { out_read.read }
  pid = Process.spawn(command, pgroup: true, in: in_read, out: out_write, err: File::NULL)
  waiter = Process.detach(pid)
  in_read.close
  out_write.close
  in_write.write(PAYLOAD_IN)
  in_write.close

  begin
    Timeout.timeout(MAX_SECONDS) { waiter.value }
  rescue Timeout::Error
    Process.kill(:TERM, -pid)
    Process.kill(:KILL, -pid) unless waiter.join(1)
    Thread.new { system("docker stop --time 1 #{name}", out: File::NULL, err: File::NULL) }
  end
  reader.value
  seconds = now - t0

  out_read.close
  [seconds, name]
end

# Returns the names of any of this probe's containers still known to docker,
# after giving the daemon a moment to finish disposing of them.
def survivors(names)
  sleep 3
  listed = `docker ps --all --format '{{.Names}}'`.split("\n")
  names & listed
end

# Returns the mean of an array of seconds, in milliseconds, to one decimal.
def mean_millis(values)
  format('%.1f', (values.sum / values.size) * 1000)
end

# Prints one row: the overshoot past max_seconds is what the learner feels.
def print_row(label, seconds)
  overshoot = seconds.map { |s| s - MAX_SECONDS }
  puts(format('%-34s %10s %14s', label, mean_millis(seconds), mean_millis(overshoot)))
end

cli = []
api = []
api_threaded = []
names = []

RUNS.times do |i|
  seconds, name = timeout_via_cli("probe_to_cli_#{i}_#{Process.pid}")
  cli << seconds
  names << name

  seconds, name = timeout_via_api("probe_to_api_#{i}_#{Process.pid}", threaded_stop: false)
  api << seconds
  names << name

  seconds, name = timeout_via_api("probe_to_apit_#{i}_#{Process.pid}", threaded_stop: true)
  api_threaded << seconds
  names << name
end

puts "image: #{IMAGE}"
puts "max_seconds: #{MAX_SECONDS}"
puts(format('%-34s %10s %14s', 'timed-out test-run', 'total ms', 'overshoot ms'))
print_row('cli: Timeout, kill group, stop', cli)
print_row('api: read deadline, stop inline', api)
print_row('api: read deadline, stop threaded', api_threaded)

left = survivors(names)
puts
puts(left.empty? ? 'containers left behind: none' : "containers left behind: #{left.inspect}")
