# The docker daemon multiplexes a container's stdout and stderr onto one
# attach stream when the container has no tty. Each frame is an 8-byte header,
# being the stream the payload belongs to, three zero bytes, and the payload
# size as a big-endian uint32, followed by the payload itself.
#
# Creating the container with Tty:true would avoid the framing altogether, and
# is the wrong choice: the payload is binary and a pty mangles it. A gzip
# stream of 20023 bytes comes back as 104 bytes and no longer inflates, and
# every \n arrives as \r\n. So the container has no tty and its two streams
# are separated here instead.
# See docs/profiling/check_tty_corrupts_binary_payload.rb
module DockerAttachFrames
  HEADER_BYTES = 8
  STDOUT_STREAM = 1
  STDERR_STREAM = 2

  # The stream ended part way through a frame, so what arrived is only part of
  # what the container sent. Nothing incomplete may reach the browser, which is
  # the same reason the payload carries a gzip CRC.
  class TruncatedStream < RuntimeError
  end

  # A frame claimed to belong to a stream the daemon does not send back. The
  # bytes being read are not the frames they are taken for, so nothing in them
  # can be trusted.
  class UnknownStream < RuntimeError
  end

  # Reads frames until the stream ends, and returns what each of stdout and
  # stderr was sent.
  def self.demultiplex(io)
    streams = { STDOUT_STREAM => +'', STDERR_STREAM => +'' }
    while (header = read_exactly(io, HEADER_BYTES))
      stream, size = header.unpack('C x3 N')
      raise UnknownStream, "frame claims stream #{stream}" unless streams.key?(stream)

      streams[stream] << read_exactly(io, size)
    end
    [streams[STDOUT_STREAM], streams[STDERR_STREAM]]
  end

  # A socket answers read(n) with what has arrived, which can be fewer than n
  # bytes, so one frame can straddle several reads. Answers nil when the stream
  # ends on a frame boundary, which is how it ends normally, and raises when it
  # ends part way through one.
  def self.read_exactly(io, size)
    buffer = +''
    while buffer.bytesize < size
      chunk = io.read(size - buffer.bytesize)
      if chunk.nil?
        return nil if buffer.empty?

        raise TruncatedStream, "wanted #{size} bytes, the stream ended after #{buffer.bytesize}"
      end
      buffer << chunk
    end
    buffer
  end
  private_class_method :read_exactly
end
