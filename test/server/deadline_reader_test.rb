require_relative '../test_base'
require_code 'deadline_reader'

class DeadlineReaderTest < TestBase

  test 'b7Ea10', %w(
  | a read with time left answers what the stream answers
  ) do
    read_end, write_end = IO.pipe
    write_end.write('hello')
    write_end.close

    reader = DeadlineReader.new(read_end, now + 5)

    assert_equal 'hel', reader.read(3)
  ensure
    read_end.close
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'b7Ea11', %w(
  | a deadline already past raises without reading
  | even when the stream has bytes waiting
  | because the run is over however much arrived
  ) do
    read_end, write_end = IO.pipe
    write_end.write('hello')
    write_end.close

    reader = DeadlineReader.new(read_end, now - 1)

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

    reader = DeadlineReader.new(read_end, now + 0.1)

    assert_raises(DeadlineReader::Expired) { reader.read(3) }
  ensure
    read_end.close
    write_end.close
  end

  private

  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
