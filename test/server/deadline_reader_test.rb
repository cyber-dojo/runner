require_relative '../test_base'
require_code 'deadline_reader'
require_code 'externals/monotonic_clock'

class DeadlineReaderTest < TestBase

  test 'b7Ea10', %w(
  | a read with time left answers what the stream answers
  ) do
    read_end, write_end = IO.pipe
    write_end.write('hello')
    write_end.close

    reader = DeadlineReader.new(read_end, max_seconds: 5, clock: MonotonicClock.new)

    assert_equal 'hel', reader.read(3)
  ensure
    read_end.close
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'b7Ea11', %w(
  | a budget already used up raises without reading
  | even when the stream has bytes waiting
  | because the run is over however much arrived
  ) do
    read_end, write_end = IO.pipe
    write_end.write('hello')
    write_end.close

    # Ten seconds pass between the reader being made and its first read, so
    # the five it was given are gone without the suite waiting for them.
    clock = ClockStub.new(from: 1000.0, advancing_by: 10.0)
    reader = DeadlineReader.new(read_end, max_seconds: 5, clock: clock)

    assert_raises(DeadlineReader::Expired) { reader.read(3) }
  ensure
    read_end.close
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'b7Ea12', %w(
  | a read still waiting when the deadline passes raises
  | which is the hung kata: the container is alive and sending nothing
  ) do
    read_end, write_end = IO.pipe # nothing is ever written to it

    reader = DeadlineReader.new(read_end, max_seconds: 0.1, clock: MonotonicClock.new)

    assert_raises(DeadlineReader::Expired) { reader.read(3) }
  ensure
    read_end.close
    write_end.close
  end
end
