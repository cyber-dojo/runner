# frozen_string_literal: true

# Answers one question: will the daemon copy a file out of a container which
# was created and never started?
#
# traffic_light.rb reads /usr/local/bin/red_amber_green.rb out of a language
# image by spawning [docker run --rm --entrypoint=cat image file]. That starts
# a container purely to read one file back, and starting is the expensive half:
# time_docker_run_split.sh puts start at about 48ms of daemon work against
# create at about 16ms.
#
# If GET /containers/{id}/archive answers for a container in the created state,
# the CLI call becomes create + archive + delete, with nothing to attach to, no
# frames to demultiplex, no deadline and no stop. If it does not, that whole
# plan is wrong and the container has to be started after all.
#
# It is how [docker cp] behaves against a stopped container, but stopped is not
# the same as never started, and this repo had not measured it.
#
# Run on the host:
#
#   ruby docs/profiling/check_archive_from_unstarted_container.rb
#   ruby docs/profiling/check_archive_from_unstarted_container.rb <image_name>

require 'json'
require 'socket'
require_relative '../../source/server/tarfile_reader'

IMAGE = ARGV[0] || 'ghcr.io/cyber-dojo-languages/gcc_assert:2733119'
SOCKET_PATH = '/var/run/docker.sock'
RAG_LAMBDA_FILENAME = '/usr/local/bin/red_amber_green.rb'

# Sends one request on its own connection and returns [code, body].
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
  code = socket.gets.to_s.split[1].to_i
  headers = read_headers(socket)
  rest = read_body(socket, headers)
  socket.close
  [code, rest]
end

# Answers the headers, downcased, up to the blank line that ends them.
def read_headers(socket)
  headers = {}
  while (line = socket.gets)
    break if ["\r\n", "\n"].include?(line)

    name, _colon, value = line.partition(':')
    headers[name.strip.downcase] = value.strip.downcase
  end
  headers
end

# The archive is a tar, so the chunk framing has to come off without any
# encoding being assumed. socket.read(size) answers ASCII-8BIT, which the
# +'' buffer adopts on the first append.
def read_body(socket, headers)
  return socket.read unless headers['transfer-encoding'] == 'chunked'

  body = +''
  while (size = socket.gets.to_s.strip.to_i(16)).positive?
    body << socket.read(size)
    socket.gets
  end
  body
end

# Returns monotonic seconds.
def now
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

# Creates a container that is never started. Nothing runs, so Cmd and the
# whole HostConfig a test-run needs are beside the point: only Image is.
def create_unstarted_container
  code, body = request('POST', '/containers/create', { 'Image' => IMAGE })
  raise "create failed: #{code} #{body}" unless [200, 201].include?(code)

  JSON.parse(body[/\{.*\}/m])['Id']
end

# Answers what the daemon says the container's state is, which is what tells
# the answer apart from one where something started it by accident.
def state_of(id)
  code, body = request('GET', "/containers/#{id}/json")
  raise "inspect failed: #{code} #{body}" unless code == 200

  JSON.parse(body[/\{.*\}/m])['State']['Status']
end

id = create_unstarted_container
begin
  state = state_of(id)

  t0 = now
  path = "/containers/#{id}/archive?path=#{RAG_LAMBDA_FILENAME}"
  code, body = request('GET', path)
  millis = format('%.1f', (now - t0) * 1000)

  puts "image:              #{IMAGE}"
  puts "container state:    #{state}"
  puts "archive code:       #{code}"
  puts "archive bytes:      #{body.to_s.bytesize}"
  puts "archive ms:         #{millis}"

  if code == 200
    files = TarFile::Reader.new(body).files
    puts "tar entries:        #{files.keys.inspect}"
    content = files.values.first.to_s
    puts "content bytes:      #{content.bytesize}"
    puts "content first line: #{content.lines.first.inspect}"

    # The bytes traffic_light.rb reads today, so that answering 200 is not
    # mistaken for answering the same thing.
    via_cli = `docker run --rm --entrypoint=cat #{IMAGE} #{RAG_LAMBDA_FILENAME}`
    puts "cli bytes:          #{via_cli.bytesize}"
    puts "same as cli:        #{content == via_cli}"
  else
    puts "body:               #{body}"
  end
ensure
  request('DELETE', "/containers/#{id}?force=true")
end
