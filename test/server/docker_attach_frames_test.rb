require_relative '../test_base'
require_code 'docker_attach_frames'
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
