require 'json'
require 'socket'

# Speaks HTTP on docker's socket, which Net::HTTP does not do. Running
# cyber-dojo.sh over it costs about 33ms less than spawning the docker CLI to
# do the same.
# See docs/profiling/time_test_run_via_daemon_api_vs_cli.rb
class DockerSocket
  # Where the docker daemon listens. A test serving a fake socket of its own is
  # the only caller that says otherwise, which is what lets a response the real
  # daemon will not send, eg a body chunked mid-json, be pinned.
  def initialize(socket_path = '/var/run/docker.sock')
    @socket_path = socket_path
  end

  # Sends one request on its own connection and answers [code, body].
  def request(method, path, body = nil)
    socket = UNIXSocket.new(socket_path)
    socket.write(request_bytes(method, path, body))
    code = read_status_code(socket)
    headers = read_headers(socket)
    body = read_body(socket, headers)
    socket.close
    [code, body]
  end

  # Asks the daemon to hand the connection over, and answers the socket with
  # its response headers already read, so the next read is the container's
  # own bytes. The daemon stops speaking HTTP on it at that point: what
  # follows is the attach stream, which DockerAttachFrames separates.
  def attach(path)
    socket = UNIXSocket.new(socket_path)
    socket.write(attach_bytes(path))
    read_status_code(socket)
    read_headers(socket)
    socket.binmode
    socket
  end

  private

  attr_reader :socket_path

  CRLF = "\r\n".freeze

  def request_bytes(method, path, body)
    lines = ["#{method} #{path} HTTP/1.1", 'Host: docker', 'Connection: close']
    if body.nil?
      "#{lines.join(CRLF)}#{CRLF}#{CRLF}"
    else
      json = JSON.generate(body)
      lines << 'Content-Type: application/json'
      lines << "Content-Length: #{json.bytesize}"
      "#{lines.join(CRLF)}#{CRLF}#{CRLF}#{json}"
    end
  end

  def attach_bytes(path)
    [
      "POST #{path} HTTP/1.1",
      'Host: docker',
      'Content-Length: 0',
      'Connection: Upgrade',
      'Upgrade: tcp',
      '',
      ''
    ].join(CRLF)
  end

  def read_status_code(socket)
    socket.gets.to_s.split[1].to_i
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

  # The daemon answers chunked whatever Connection it is asked for, so the
  # framing has to come off. Anything else is a read to the end of the
  # stream, which Connection: close is what makes safe.
  def read_body(socket, headers)
    if headers['transfer-encoding'] == 'chunked'
      read_chunked_body(socket)
    else
      socket.read
    end
  end

  # Each chunk is its size in hex, then the bytes, then a blank line. A size
  # of zero ends the body.
  def read_chunked_body(socket)
    body = +''
    while (size = socket.gets.to_s.strip.to_i(16)).positive?
      body << socket.read(size)
      socket.gets
    end
    body
  end
end
