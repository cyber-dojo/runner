class DaemonStub
  # as passed to set_context(daemon:), standing in for the docker daemon.
  #
  # Answers create, start and stop, and hands back an attach stream carrying
  # whatever the container is said to have written to its stdout, framed the
  # way the daemon frames it. timed_out: true makes that stream stand in for a
  # container which never finishes what it is saying.

  def initialize(stdout: '', create_code: 201, create_body: '{"Id":"c0ffee"}', timed_out: false, archive: nil)
    @stdout = stdout
    @create_code = create_code
    @create_body = create_body
    @timed_out = timed_out
    @archive = archive
  end

  # The only create this answers is a container's. Matching the path rather
  # than the word keeps an image pull, POST /images/create, out of it.
  # An archive is TrafficLight reading the rag-lambda out of the image, which
  # only a test that was given one can answer.
  def request(_method, path, _body = nil)
    if path.start_with?('/containers/create')
      [@create_code, @create_body]
    elsif path.include?('/archive?')
      archive_response
    else
      [204, '']
    end
  end

  def archive_response
    return [200, @archive] unless @archive.nil?

    [404, '{"message":"DaemonStub was given no archive: to answer with"}']
  end

  def attach(_path)
    AttachStreamStub.new(@stdout, timed_out: @timed_out)
  end

  # Stands in for the hijacked socket.
  class AttachStreamStub
    STDOUT_STREAM = 1

    def initialize(stdout, timed_out: false)
      @bytes = framed(STDOUT_STREAM, stdout)
      @at = 0
      @timed_out = timed_out
    end

    # DeadlineReader sets the budget left before every read, which a real
    # socket honours. Nothing here blocks, so it is ignored.
    attr_writer :timeout

    def write(_bytes); end
    def close_write; end

    # IO::TimeoutError is what a real socket raises when the budget set on it
    # runs out, and what DeadlineReader turns into Expired.
    def read(size)
      raise IO::TimeoutError if @timed_out
      return nil if @at >= @bytes.bytesize

      chunk = @bytes.byteslice(@at, size)
      @at += chunk.bytesize
      chunk
    end

    private

    # An 8-byte header, being the stream, three zero bytes, and the payload
    # size as a big-endian uint32, then the payload.
    def framed(stream, payload)
      [stream, payload.bytesize].pack('C x3 N') + payload
    end
  end
end
