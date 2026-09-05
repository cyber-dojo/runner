require_relative '../test_base'
require_code 'docker_attach_frames'
require_code 'deadline_reader'
require_code 'externals/monotonic_clock'
require 'stringio'

class DockerAttachFramesTest < TestBase

  test 'e4Fb10', %w(
  | one stdout frame demultiplexes to stdout
  | and stderr stays empty
  ) do
    stdout, stderr = DockerAttachFrames.demultiplex(StringIO.new(frame(STDOUT_STREAM, 'hello')))

    assert_equal 'hello', stdout
    assert_equal '', stderr
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'e4Fb11', %w(
  | one stderr frame demultiplexes to stderr
  | and stdout stays empty
  ) do
    stdout, stderr = DockerAttachFrames.demultiplex(StringIO.new(frame(STDERR_STREAM, 'ouch')))

    assert_equal '', stdout
    assert_equal 'ouch', stderr
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'e4Fb12', %w(
  | interleaved frames are read until the stream ends
  | and each stream is rejoined in the order its frames arrived
  ) do
    frames = [
      frame(STDOUT_STREAM, 'the '),
      frame(STDERR_STREAM, 'warning: '),
      frame(STDOUT_STREAM, 'quick '),
      frame(STDERR_STREAM, 'unused variable'),
      frame(STDOUT_STREAM, 'brown fox')
    ].join

    stdout, stderr = DockerAttachFrames.demultiplex(StringIO.new(frames))

    assert_equal 'the quick brown fox', stdout
    assert_equal 'warning: unused variable', stderr
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'e4Fb13', %w(
  | a read answering fewer bytes than asked for does not lose any
  | which is how a socket behaves once the payload spans several packets
  ) do
    frames = [
      frame(STDOUT_STREAM, 'the quick '),
      frame(STDERR_STREAM, 'warning: unused'),
      frame(STDOUT_STREAM, 'brown fox')
    ].join

    stdout, stderr = DockerAttachFrames.demultiplex(TrickleIo.new(frames, 3))

    assert_equal 'the quick brown fox', stdout
    assert_equal 'warning: unused', stderr
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'e4Fb14', %w(
  | a frame whose payload is cut short raises
  | rather than answering the bytes that did arrive
  | because a truncated payload must not reach the browser
  ) do
    whole = frame(STDOUT_STREAM, '0123456789')
    cut_short = whole[0...(HEADER_BYTES + 4)]

    assert_raises(DockerAttachFrames::TruncatedStream) do
      DockerAttachFrames.demultiplex(StringIO.new(cut_short))
    end
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'e4Fb15', %w(
  | a frame belonging to neither stdout nor stderr raises
  | because the daemon sends back only those two
  | and a header that says otherwise is not a header
  ) do
    assert_raises(DockerAttachFrames::UnknownStream) do
      DockerAttachFrames.demultiplex(StringIO.new(frame(STDIN_STREAM, 'echo')))
    end
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'e4Fb16', %w(
  | frames arriving on a real stream, read under a deadline, demultiplex
  | which is the pairing a run of cyber-dojo.sh relies on
  | and which neither module can show on its own
  ) do
    read_end, write_end = IO.pipe
    write_end.write(frame(STDOUT_STREAM, 'the quick '))
    write_end.write(frame(STDERR_STREAM, 'warning: unused'))
    write_end.write(frame(STDOUT_STREAM, 'brown fox'))
    write_end.close

    reader = DeadlineReader.new(read_end, max_seconds: 5, clock: MonotonicClock.new)
    stdout, stderr = DockerAttachFrames.demultiplex(reader)

    assert_equal 'the quick brown fox', stdout
    assert_equal 'warning: unused', stderr
  ensure
    read_end.close
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'e4Fb17', %w(
  | a stream that stops arriving raises when the deadline passes
  | rather than answering the frames that did arrive
  | which is the hung kata: the container is alive and sending no more
  ) do
    read_end, write_end = IO.pipe
    write_end.write(frame(STDOUT_STREAM, 'the quick ')) # and then nothing more

    reader = DeadlineReader.new(read_end, max_seconds: 0.1, clock: MonotonicClock.new)

    assert_raises(DeadlineReader::Expired) do
      DockerAttachFrames.demultiplex(reader)
    end
  ensure
    read_end.close
    write_end.close
  end

  private

  HEADER_BYTES = 8

  # Answers read(n) with at most `most` bytes, the way a socket answers with
  # what has arrived so far. StringIO always answers the whole n, so it cannot
  # show this. Three is deliberately smaller than a frame header.
  class TrickleIo
    def initialize(bytes, most)
      @bytes = bytes
      @most = most
      @at = 0
    end

    def read(count)
      return nil if @at >= @bytes.bytesize

      chunk = @bytes.byteslice(@at, [count, @most].min)
      @at += chunk.bytesize
      chunk
    end
  end

  # A docker attach frame is an 8-byte header, being the stream it belongs to,
  # three zero bytes, and the payload size as a big-endian uint32, followed by
  # the payload itself.
  STDIN_STREAM = 0
  STDOUT_STREAM = 1
  STDERR_STREAM = 2

  def frame(stream, payload)
    [stream, payload.bytesize].pack('C x3 N') + payload
  end
end
