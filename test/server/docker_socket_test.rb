require_relative '../test_base'
require_code 'externals/docker_socket'
require 'fileutils'
require 'socket'

class DockerSocketTest < TestBase

  test 'a3Bd10', %w(
  | a request answers the response code and body
  ) do
    code, body = against_server("HTTP/1.1 201 Created\r\nConnection: close\r\n\r\n{\"Id\":\"abc\"}") do |path|
      DockerSocket.new(path).request('POST', '/containers/create')
    end

    assert_equal 201, code
    assert_equal '{"Id":"abc"}', body
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'a3Bd11', %w(
  | a request with a body says it is json and how long it is
  | and the daemon is asked to close the connection
  | so that reading the response is a read to the end of the stream
  ) do
    against_server("HTTP/1.1 204 No Content\r\nConnection: close\r\n\r\n") do |path|
      DockerSocket.new(path).request('POST', '/containers/abc/start', { 'Detach' => false })
    end

    assert_equal [
      'POST /containers/abc/start HTTP/1.1',
      'Host: docker',
      'Connection: close',
      'Content-Type: application/json',
      'Content-Length: 16',
      '',
      '{"Detach":false}'
    ].join("\r\n"), @request_bytes
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'a3Bd12', %w(
  | an attach upgrades the connection and answers the stream itself
  | positioned past the response headers
  | so what is read next is the container's own bytes
  ) do
    upgraded = [
      'HTTP/1.1 101 UPGRADED',
      'Content-Type: application/vnd.docker.raw-stream',
      'Connection: Upgrade',
      'Upgrade: tcp',
      '',
      'raw-stream-bytes'
    ].join("\r\n")

    bytes = against_server(upgraded) do |path|
      DockerSocket.new(path).attach('/containers/abc/attach?stream=1&stdout=1').read
    end

    assert_equal 'raw-stream-bytes', bytes
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'a3Bd13', %w(
  | an attach asks for the upgrade, and says it is sending nothing
  | and does not ask for the connection to be closed
  | because the connection is what it wants to keep
  ) do
    upgraded = "HTTP/1.1 101 UPGRADED\r\nUpgrade: tcp\r\n\r\n"
    against_server(upgraded) do |path|
      DockerSocket.new(path).attach('/containers/abc/attach?stream=1').read
    end

    assert_equal [
      'POST /containers/abc/attach?stream=1 HTTP/1.1',
      'Host: docker',
      'Content-Length: 0',
      'Connection: Upgrade',
      'Upgrade: tcp',
      '',
      ''
    ].join("\r\n"), @request_bytes
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'a3Bd14', %w(
  | a chunked response answers the body with its chunk framing removed
  | which the daemon sends whatever Connection it is asked for
  ) do
    chunked = [
      'HTTP/1.1 201 Created',
      'Transfer-Encoding: chunked',
      '',
      '6',
      '{"Id":',
      '9',
      '"c0ffee"}',
      '0',
      '',
      ''
    ].join("\r\n")

    code, body = against_server(chunked) do |path|
      DockerSocket.new(path).request('POST', '/containers/create')
    end

    assert_equal 201, code
    assert_equal '{"Id":"c0ffee"}', body
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'a3Bd15', %w(
  | a block that raises before connecting says so
  | rather than hanging on a connection that is never going to arrive
  | which is what every red test in this file depends on
  ) do
    error = assert_raises(RuntimeError) do
      against_server("HTTP/1.1 200 OK\r\n\r\n") { raise 'the block failed' }
    end

    assert_equal 'the block failed', error.message
  end

  private

  # Serves one connection on a unix socket, answering with the given bytes,
  # and returns whatever the block returns. The daemon is not needed to say
  # what the client makes of a response.
  # The listener and its thread are made before the region that disposes of
  # them, so there is nothing for that region to guard against being nil, and
  # a failure to make either of them says so itself rather than being masked.
  def against_server(response)
    path = "/tmp/#{id58}.sock"
    FileUtils.rm_f(path)
    server = UNIXServer.new(path)
    served = Thread.new do
      connection = server.accept
      @request_bytes = connection.readpartial(4096)
      connection.write(response)
      connection.close
    rescue StandardError
      nil # the block raised before connecting, so no connection ever arrives
    end
    begin
      yield(path)
    ensure
      # Closing the listener first is what unblocks an accept still waiting for
      # a connection that is never going to come. Without it a failing block
      # deadlocks the join, which is every red test.
      server.close
      served.join(JOIN_SECONDS)
      served.kill
      FileUtils.rm_f(path)
    end
  end

  JOIN_SECONDS = 2
end
