# frozen_string_literal: true

# Checks whether a container created with Tty:true can carry the payload.
#
# The daemon multiplexes stdout and stderr onto one attach stream, with an
# 8-byte header per frame, which is what docker_attach_frames.rb separates.
# Tty:true removes the framing and would remove the need for that module, so
# the question is whether it is safe. It is not: a pty runs in cooked mode and
# translates \n to \r\n on the way out, and the payload is a gzipped tar.
#
# Two bodies, each run both ways:
#
#   newlines   printf of three newline-separated letters, so the translation
#              can be seen byte for byte
#   payload    a gzip stream, which is what a test-run actually returns, checked
#              by inflating it the way the runner does
#
# Run on the host:
#
#   ruby docs/profiling/check_tty_corrupts_binary_payload.rb

require 'json'
require 'socket'
require 'zlib'
require_relative '../../source/server/docker_attach_frames'

IMAGE = ARGV[0] || 'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a'
SOCKET_PATH = '/var/run/docker.sock'

UID = 41_966
GID = 51_966

NEWLINES_BODY = "printf 'a\\nb\\nc\\n'"
PAYLOAD_BODY = 'head -c 20000 /dev/urandom | gzip -1'

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

# Sends one request on its own connection and returns its body.
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
  read_headers(socket)
  rest = socket.read
  socket.close
  rest
end

# The container config, differing only in whether it has a tty.
def create_body(body, tty)
  {
    'Image' => IMAGE,
    'Cmd' => ['bash', '-c', body],
    'Entrypoint' => [],
    'User' => "#{UID}:#{GID}",
    'AttachStdout' => true,
    'AttachStderr' => true,
    'Tty' => tty,
    'HostConfig' => {
      'AutoRemove' => true,
      'Init' => true,
      'Memory' => 2 * 1024 * 1024 * 1024,
      'NetworkMode' => 'none',
      'PidsLimit' => 128
    }
  }
end

# Opens the hijacked attach stream.
def attach(id)
  socket = daemon_socket
  path = "/containers/#{id}/attach?stream=1&stdout=1&stderr=1"
  socket.write(
    "POST #{path} HTTP/1.1\r\nHost: docker\r\nContent-Length: 0\r\n" \
    "Upgrade: tcp\r\nConnection: Upgrade\r\n\r\n"
  )
  read_headers(socket)
  socket
end

# Runs the body and returns the bytes the container sent to stdout. With a tty
# the stream carries no frames, so it is read as it stands; without one the
# frames are separated the way the runner separates them.
def stdout_of(body, tty)
  created = request('POST', '/containers/create', create_body(body, tty))
  id = JSON.parse(created[/\{.*\}/m])['Id']
  stream = attach(id)
  stream.binmode
  request('POST', "/containers/#{id}/start")
  bytes = if tty
            stream.read
          else
            DockerAttachFrames.demultiplex(stream).first
          end
  stream.close
  bytes.to_s
end

# Returns whether the bytes are a gzip stream the runner would accept, which
# means the CRC32 and length trailer both check out.
def inflates?(bytes)
  Zlib::GzipReader.new(StringIO.new(bytes)).read
  true
rescue StandardError
  false
end

require 'stringio'

puts "image: #{IMAGE}"
puts

no_tty = stdout_of(NEWLINES_BODY, false)
tty = stdout_of(NEWLINES_BODY, true)
puts(format('%-28s %s', 'newlines, Tty false', no_tty.bytes.inspect))
puts(format('%-28s %s', 'newlines, Tty true', tty.bytes.inspect))
puts

no_tty = stdout_of(PAYLOAD_BODY, false)
tty = stdout_of(PAYLOAD_BODY, true)
puts(format('%-28s %6d bytes  inflates: %s', 'gzip payload, Tty false', no_tty.bytesize, inflates?(no_tty)))
puts(format('%-28s %6d bytes  inflates: %s', 'gzip payload, Tty true', tty.bytesize, inflates?(tty)))
