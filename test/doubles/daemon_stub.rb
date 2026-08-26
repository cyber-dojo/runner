class DaemonStub
  # as passed to set_context(daemon:), standing in for the docker daemon.
  #
  # Answers create, start and stop, and hands back an attach stream carrying
  # whatever the container is said to have written to its stdout, framed the
  # way the daemon frames it.

  def initialize(stdout: '', create_code: 201, create_body: '{"Id":"c0ffee"}')
    @stdout = stdout
    @create_code = create_code
    @create_body = create_body
  end

  def request(_method, path, _body = nil)
    if path.include?('create')
      [@create_code, @create_body]
    else
      [204, '']
    end
  end

  def attach(_path)
    AttachStreamStub.new(@stdout)
  end

  # Stands in for the hijacked socket.
  class AttachStreamStub
    STDOUT_STREAM = 1

    def initialize(stdout)
      @bytes = framed(STDOUT_STREAM, stdout)
      @at = 0
    end

    # DeadlineReader sets the budget left before every read, which a real
    # socket honours. Nothing here blocks, so it is ignored.
    attr_writer :timeout

    def write(_bytes); end
    def close_write; end

    def read(size)
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
