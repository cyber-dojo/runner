# frozen_string_literal: true

# Measures a test-run driven straight against the docker daemon, against the
# same test-run driven through the docker CLI. A test-run is one run of a
# kata's cyber-dojo.sh, which is what the browser's [test] button asks for.
#
# Every test-run currently spawns the CLI, which does HTTP against
# /var/run/docker.sock on the runner's behalf: create, attach, start, proxy the
# streams, and with --rm wait for the removal before exiting. The runner waits
# on that process, so it inherits all of it. Doing the same calls directly
# should drop both the CLI process spawn and the wait for the removal, while
# keeping AutoRemove, which is a property of the container rather than of
# whoever is connected to it.
#
# Both variants create with AutoRemove, feed the same tgz on stdin, and read
# the same payload back, so the difference is the client and nothing else.
#
# Run on the host:
#
#   ruby docs/profiling/time_test_run_via_daemon_api_vs_cli.rb
#
# Not inside the runner image on a developer machine whose architecture differs
# from it. What is being compared is largely the cost of the docker CLI's own
# process, and emulating that process inflates exactly the thing in question:
# the same two rows read 203.6 and 67.6 emulated, against 116.4 and 68.1 here.

require 'json'
require 'socket'
require_relative '../../source/server/lib/tgz'

IMAGE = ARGV[0] || 'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a'
RUNS = 10
SOCKET_PATH = '/var/run/docker.sock'

UID = 41_966
GID = 51_966

# What the container does with the test-run: take the files on stdin and send a
# payload back, which is the shape of cyber_dojo_main.sh without the kata.
BODY = 'tar -C /tmp -zxf - && dd if=/dev/zero bs=1024 count=64 status=none | gzip -1'

# The files a test-run delivers, sized like a small kata's.
PAYLOAD_IN = TGZ.of({
                      'tmp/hiker.pl' => "sub answer {\n  return 6 * 9;\n}\n\n1;\n",
                      'tmp/hiker.t' => "use Test::Simple tests => 1;\nok(answer() == 42);\n",
                      'tmp/cyber-dojo.sh' => "perl hiker.t\n"
                    })

# The container config the CLI would build from runner.rb's flags. Kept in the
# API's own vocabulary rather than the CLI's, since that is what is being
# compared.
def create_body(cmd)
  {
    'Image' => IMAGE,
    'Cmd' => ['bash', '-c', cmd],
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
      'SecurityOpt' => ['no-new-privileges'],
      'Tmpfs' => {
        '/sandbox' => "exec,size=250M,uid=#{UID},gid=#{GID}",
        '/tmp' => 'exec,size=250M,mode=1777'
      },
      'Ulimits' => [
        { 'Name' => 'core', 'Soft' => 0, 'Hard' => 0 },
        { 'Name' => 'fsize', 'Soft' => 268_435_456, 'Hard' => 268_435_456 },
        { 'Name' => 'locks', 'Soft' => 1024, 'Hard' => 1024 },
        { 'Name' => 'nofile', 'Soft' => 1024, 'Hard' => 1024 },
        { 'Name' => 'nproc', 'Soft' => 1024, 'Hard' => 1024 },
        { 'Name' => 'stack', 'Soft' => 16_777_216, 'Hard' => 16_777_216 },
        { 'Name' => 'data', 'Soft' => 4_294_967_296, 'Hard' => 4_294_967_296 }
      ]
    }
  }
end

# Returns monotonic seconds.
def now
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

# Returns a socket connected to the daemon.
def daemon_socket
  UNIXSocket.new(SOCKET_PATH)
end

# Reads and discards one HTTP response's headers, returning the status code and
# whatever the headers said about the body.
def read_headers(socket)
  status_line = socket.gets
  code = status_line.to_s.split(' ')[1].to_i
  headers = {}
  while (line = socket.gets)
    break if line == "\r\n" || line == "\n"

    name, value = line.split(':', 2)
    headers[name.to_s.strip.downcase] = value.to_s.strip
  end
  [code, headers]
end

# Sends one request on its own connection and returns [code, body], for the
# calls whose response is ordinary JSON rather than a hijacked stream.
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
  code, = read_headers(socket)
  rest = socket.read
  socket.close
  [code, rest]
end

# Opens the hijacked attach stream, over which stdin is written and the
# multiplexed output is read.
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

# Reads the attach stream to its end, returning the stdout bytes. Each frame
# carries an 8-byte header: the stream it belongs to, three padding bytes, and
# the payload size big-endian.
def read_frames(socket)
  stdout = +''
  loop do
    header = socket.read(8)
    break if header.nil? || header.bytesize < 8

    stream, size = header.unpack('C x3 N')
    payload = size.zero? ? '' : socket.read(size)
    break if payload.nil?

    stdout << payload if stream == 1
  end
  stdout
end

# Times one test-run driven straight against the daemon.
def test_run_via_api(name)
  t0 = now
  code, body = request('POST', "/containers/create?name=#{name}", create_body(BODY))
  raise "create failed: #{code} #{body}" unless [200, 201].include?(code)

  id = JSON.parse(body[/\{.*\}/m])['Id']
  stream = attach(id)
  code, body = request('POST', "/containers/#{id}/start")
  raise "start failed: #{code} #{body}" unless [200, 204].include?(code)

  stream.write(PAYLOAD_IN)
  # Half-close, so the container's [tar -zxf -] sees EOF on stdin. Without it
  # tar waits for more input and the test-run never completes.
  stream.close_write
  read_frames(stream)
  stream.close
  now - t0
end

# Starts a container that sits idle, which is what a pool holds ready. Returns
# its id, and the seconds it took, since that is the work the refill thread
# does after a test-run rather than during one.
def start_idle_container(name)
  t0 = now
  body = create_body('sleep 300')
  body['OpenStdin'] = false
  body['StdinOnce'] = false
  body['AttachStdin'] = false
  code, response = request('POST', "/containers/create?name=#{name}", body)
  raise "create failed: #{code} #{response}" unless [200, 201].include?(code)

  id = JSON.parse(response[/\{.*\}/m])['Id']
  code, response = request('POST', "/containers/#{id}/start")
  raise "start failed: #{code} #{response}" unless [200, 204].include?(code)

  [id, now - t0]
end

# Times a test-run into a pooled container, over the socket. An exec is created
# and then started, and starting it hijacks the connection the same way attach
# does, so the payload and the frames travel over that one socket.
def test_run_via_api_pool(id)
  t0 = now
  code, response = request('POST', "/containers/#{id}/exec", {
                             'AttachStdin' => true,
                             'AttachStdout' => true,
                             'AttachStderr' => true,
                             'Tty' => false,
                             'User' => "#{UID}:#{GID}",
                             'Cmd' => ['bash', '-c', BODY]
                           })
  raise "exec create failed: #{code} #{response}" unless [200, 201].include?(code)

  exec_id = JSON.parse(response[/\{.*\}/m])['Id']

  stream = daemon_socket
  payload = JSON.generate({ 'Detach' => false, 'Tty' => false })
  stream.write(
    "POST /exec/#{exec_id}/start HTTP/1.1\r\nHost: docker\r\n" \
    "Content-Type: application/json\r\nContent-Length: #{payload.bytesize}\r\n" \
    "Upgrade: tcp\r\nConnection: Upgrade\r\n\r\n#{payload}"
  )
  read_headers(stream)

  stream.write(PAYLOAD_IN)
  stream.close_write
  read_frames(stream)
  stream.close
  now - t0
end

# Times a test-run driven by spawning a docker CLI command, writing the payload
# to its stdin and reading its stdout, the way capture3_with_timeout.rb does.
def spawned_test_run(command)
  in_read, in_write = IO.pipe
  out_read, out_write = IO.pipe
  in_write.binmode
  out_read.binmode

  t0 = now
  pid = Process.spawn(command, pgroup: true, in: in_read, out: out_write, err: File::NULL)
  waiter = Process.detach(pid)
  in_read.close
  out_write.close
  in_write.write(PAYLOAD_IN)
  in_write.close
  out_read.read
  waiter.value
  seconds = now - t0

  out_read.close
  seconds
end

# Times the test-run driven through the CLI, as runner.rb does it now.
def test_run_via_cli(name)
  spawned_test_run([
    'docker run --rm --init --interactive',
    "--user=#{UID}:#{GID}",
    "--tmpfs /sandbox:exec,size=250M,uid=#{UID},gid=#{GID}",
    '--tmpfs /tmp:exec,size=250M,mode=1777',
    '--memory=2g --net=none --pids-limit=128 --security-opt=no-new-privileges',
    "--name #{name}",
    "--entrypoint=''",
    IMAGE,
    %(bash -c "#{BODY}")
  ].join(' '))
end

# Times a test-run into a container the CLI started earlier and which has only
# ever run sleep, which is the best a pool built on the CLI can do. Included
# here so it is measured in the same run as the other two rather than compared
# across probes and machines.
def test_run_via_cli_prestarted(name)
  prepare = [
    'docker run --detach --init --interactive',
    "--user=#{UID}:#{GID}",
    "--tmpfs /sandbox:exec,size=250M,uid=#{UID},gid=#{GID}",
    '--tmpfs /tmp:exec,size=250M,mode=1777',
    '--memory=2g --net=none --pids-limit=128 --security-opt=no-new-privileges',
    "--name #{name}",
    "--entrypoint=''",
    IMAGE,
    'sleep 300'
  ].join(' ')
  system(prepare, out: File::NULL, err: File::NULL)

  seconds = spawned_test_run(%(docker exec --interactive #{name} bash -c "#{BODY}"))
  system("docker rm --force #{name}", out: File::NULL, err: File::NULL)
  seconds
end

# Returns the mean of an array of seconds, in milliseconds, to one decimal.
def mean_millis(values)
  format('%.1f', (values.sum / values.size) * 1000)
end

api = []
cli = []
cli_prestarted = []
api_pool = []
refill = []

RUNS.times do |i|
  api << test_run_via_api("probe_api_#{i}_#{Process.pid}")
  cli << test_run_via_cli("probe_cli_#{i}_#{Process.pid}")
  cli_prestarted << test_run_via_cli_prestarted("probe_warm_#{i}_#{Process.pid}")

  # Prepared before the clock starts, exactly as a pool prepares it before the
  # learner asks for a test-run.
  id, seconds = start_idle_container("probe_apipool_#{i}_#{Process.pid}")
  refill << seconds
  api_pool << test_run_via_api_pool(id)
  request('POST', "/containers/#{id}/kill")
end

puts "image: #{IMAGE}"
puts(format('%-40s %10s', 'test-run', 'ms'))
puts(format('%-40s %10s', 'via docker CLI (docker run --rm)', mean_millis(cli)))
puts(format('%-40s %10s', 'via docker CLI, pre-started (exec)', mean_millis(cli_prestarted)))
puts(format('%-40s %10s', 'via daemon API (AutoRemove, no wait)', mean_millis(api)))
puts(format('%-40s %10s', 'via daemon API, pre-started (exec)', mean_millis(api_pool)))
puts
puts(format('%-40s %10s', 'off the test-run: preparing it in advance', mean_millis(refill)))
