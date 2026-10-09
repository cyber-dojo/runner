class DockerDaemonStub
  # as passed to set_context(docker:), standing in for the docker daemon in a
  # whole test-run.
  #
  # Answers create, start, exec, stop and the spare count, and hands back a
  # stream carrying whatever the container is said to have written to its
  # stdout, framed the way the daemon frames it. timed_out: true makes that
  # stream stand in for a container which never finishes what it is saying. An
  # archive is TrafficLight reading the rag-lambda out of the image, which only
  # a test that was given one can answer.
  #
  # The spare count is answered because a test-run warms a spare on a thread
  # nobody waits on, so a stub without it raises there instead of in a test,
  # and ruby reports that on stderr in the middle of a run that passes. An
  # empty list says the node holds no spares, which is what a test-run with no
  # pool behind it means.

  def initialize(stdout: '', create_code: 201, create_body: '{"Id":"c0ffee"}',
                 exec_code: 201, exec_body: '{"Id":"e5ec1d"}',
                 timed_out: false, archive: nil, containers_named_body: '[]')
    @stdout = stdout
    @create_code = create_code
    @create_body = create_body
    @exec_code = exec_code
    @exec_body = exec_body
    @timed_out = timed_out
    @archive = archive
    @containers_named_body = containers_named_body
  end

  def containers_named(_name)
    [200, @containers_named_body]
  end

  def create_container(_config, name: nil)
    [@create_code, @create_body]
  end

  def start_container(_id)
    [204, '']
  end

  def create_exec(_container_id, _config)
    [@exec_code, @exec_body]
  end

  def start_exec(_exec_id)
    AttachStreamStub.new(@stdout, timed_out: @timed_out)
  end

  def stop_container(_id, seconds:)
    [204, '']
  end

  def read_file(_id, _path)
    return [200, @archive] unless @archive.nil?

    [404, '{"message":"DockerDaemonStub was given no archive: to answer with"}']
  end

  def remove_container(_id)
    [204, '']
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
