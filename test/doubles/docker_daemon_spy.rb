class DockerDaemonSpy
  # as passed to set_context(docker:), for the calls whose endpoints and order
  # a test wants to pin. Answers each canned [code,body] in turn, and remembers
  # every call by the name of the endpoint and the arguments it was given, so
  # nothing has to match on a docker URL to know what was asked.
  #
  # start_exec hands back a stream carrying whatever the container is said to
  # have written, framed the way the daemon frames it, and remembers what was
  # written to it. stalls: true makes that stream stand in for a container
  # which is alive and saying nothing.

  def initialize(responses, frames: [], stalls: false)
    @responses = responses
    @frames = frames
    @stalls = stalls
    @calls = []
  end

  attr_reader :calls

  def image_names
    answer(:image_names)
  end

  def pull_image(image_name)
    answer(:pull_image, image_name)
  end

  def containers_named(name)
    answer(:containers_named, name)
  end

  def create_container(config, name: nil)
    answer(:create_container, config, name)
  end

  def start_container(id)
    answer(:start_container, id)
  end

  def stop_container(id, seconds:)
    answer(:stop_container, id, seconds)
  end

  def read_file(id, path)
    answer(:read_file, id, path)
  end

  def remove_container(id)
    answer(:remove_container, id)
  end

  def create_exec(container_id, config)
    answer(:create_exec, container_id, config)
  end

  def start_exec(exec_id)
    @calls << [:start_exec, exec_id]
    @stream = AttachStreamSpy.new(@frames, @stalls)
  end

  def written
    @stream.written
  end

  def write_half_closed
    @stream.write_half_closed
  end

  # The endpoints a test asked for, in the order it asked for them.
  def endpoints
    @calls.map(&:first)
  end

  private

  # Remembers one call and answers the next canned response, there being no
  # response left to answer once a test has asked for more than it set up.
  def answer(endpoint, *args)
    @calls << [endpoint, *args]
    @responses.shift
  end

  # Stands in for the hijacked socket. It reads back the given frames as the
  # daemon would frame them, and remembers what was written to it and whether
  # the writing half was shut down.
  class AttachStreamSpy
    attr_reader :written, :write_half_closed

    def initialize(frames, stalls = false)
      @bytes = frames.map { |stream, payload| framed(stream, payload) }.join
      @stalls = stalls
      @at = 0
      @written = +''
      @write_half_closed = false
    end

    # DeadlineReader sets the budget left on the stream before every read,
    # which a real socket honours. Nothing here blocks, so it is ignored.
    attr_writer :timeout

    def write(bytes)
      @written << bytes
    end

    def close_write
      @write_half_closed = true
    end

    # A stalling container is alive and sending nothing, which a real socket
    # answers by blocking until its timeout expires.
    def read(size)
      raise IO::TimeoutError if @stalls
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
