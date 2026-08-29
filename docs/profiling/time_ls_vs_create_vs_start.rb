# frozen_string_literal: true

# Measures what it would cost a test-run to find its spare on the daemon
# instead of in its own memory.
#
# SparePool is per worker, so a spare one worker warmed is one the next
# test-run cannot claim unless it happens to land on that worker. Asking the
# daemon which spares the node holds would fix that, and would also replace
# two of the four caps in docs/pre-started-container-pool.md with one true
# count. The price is a listing on the learner's path, which is the thing
# section 0 took off it.
#
# So the question is what a listing costs beside the create and the start it
# would save, and whether it grows with how many containers the daemon is
# tracking. All three are timed here, at several such counts:
#
#   ls      GET /containers/json filtered by the spare name prefix
#   create  POST /containers/create, the call a miss pays
#   start   POST /containers/{id}/start, the other half of a miss
#
# Run on the host, not inside the runner image on a machine whose architecture
# differs from it:
#
#   ruby docs/profiling/time_ls_vs_create_vs_start.rb [IMAGE]

require 'cgi'
require 'json'
require 'socket'

IMAGE = ARGV[0] || 'ghcr.io/cyber-dojo-languages/python_pytest:e8d7fcd'
SOCKET_PATH = '/var/run/docker.sock'
RUNS = 20
LEVELS = [0, 8, 32].freeze
NAME_PREFIX = "probe_lsprice_#{Process.pid}"

UID = 41_966
GID = 51_966

# The container a spare is: the image, a sleep to keep it there to be exec'd
# into, and the limits runner.rb creates one with.
def create_body
  {
    'Image' => IMAGE,
    'Cmd' => ['sleep', '600'],
    'Entrypoint' => [],
    'User' => "#{UID}:#{GID}",
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
      }
    }
  }
end

def now
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

# The daemon answers chunked, so the body carries its chunk framing as well as
# its JSON. Only the JSON is wanted here.
def json_of(body)
  JSON.parse(body[/[{\[].*[}\]]/m])
end

# Reads one HTTP response's headers off the socket, answering its status.
def read_status(socket)
  status_line = socket.gets
  while (line = socket.gets)
    break if line == "\r\n" || line == "\n"
  end
  status_line.to_s.split(' ')[1].to_i
end

# Sends one request on its own connection and answers [status, body].
def request(method, path, body = nil)
  socket = UNIXSocket.new(SOCKET_PATH)
  payload = body.nil? ? nil : JSON.generate(body)
  lines = ["#{method} #{path} HTTP/1.1", 'Host: docker', 'Connection: close']
  unless payload.nil?
    lines << 'Content-Type: application/json'
    lines << "Content-Length: #{payload.bytesize}"
  end
  socket.write("#{lines.join("\r\n")}\r\n\r\n")
  socket.write(payload) unless payload.nil?
  status = read_status(socket)
  rest = socket.read
  socket.close
  [status, rest]
end

# The listing a claim would do: every running container whose name starts with
# the spare prefix. The daemon's name filter is a substring match.
def ls
  filters = JSON.generate({ 'name' => [NAME_PREFIX] })
  request('GET', "/containers/json?filters=#{CGI.escape(filters)}")
end

def create(name)
  request('POST', "/containers/create?name=#{name}", create_body)
end

def start(id)
  request('POST', "/containers/#{id}/start")
end

def remove(id)
  request('DELETE', "/containers/#{id}?force=true")
end

# Answers the mean milliseconds of RUNS calls to the given block.
def timed(runs)
  t0 = now
  runs.times { |i| yield i }
  ((now - t0) / runs * 1000).round(1)
end

created = []
at_exit do
  created.each { |id| remove(id) }
end

# Brings the number of containers the daemon is tracking up to a level, and
# leaves them running while the calls are timed.
def top_up(created, to)
  while created.size < to
    _, body = create("#{NAME_PREFIX}_idle_#{created.size}")
    id = json_of(body)['Id']
    start(id)
    created << id
  end
end

puts "image: #{IMAGE}"
puts "runs: #{RUNS}"
puts
printf("%8s %10s %12s %11s\n", 'tracked', 'ls ms', 'create ms', 'start ms')

LEVELS.each do |level|
  top_up(created, level)

  ls_ms = timed(RUNS) { ls }

  made = []
  create_ms = timed(RUNS) do |i|
    _, body = create("#{NAME_PREFIX}_timed_#{level}_#{i}")
    made << json_of(body)['Id']
  end

  start_ms = timed(made.size) { |i| start(made[i]) }

  made.each { |id| remove(id) }

  printf("%8s %10s %12s %11s\n", level, ls_ms, create_ms, start_ms)
end
