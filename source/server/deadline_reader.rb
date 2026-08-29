# Reads from a stream under an absolute deadline.
#
# A run of cyber-dojo.sh over the daemon socket has no child process to wait
# on, so what bounds it is the reading of the attach stream. The deadline is
# absolute rather than per-read, because it bounds the whole run: a container
# dribbling output would never trip a timeout that started again on every
# read.
class DeadlineReader
  # The deadline passed with the run unfinished.
  class Expired < RuntimeError
  end

  # The budget starts here, which is when the container has everything it
  # needs to get going. Taking the seconds rather than the deadline is what
  # keeps the deadline and every reading of it on one clock: two clocks have
  # two origins, and the difference between them is not a duration.
  def initialize(io, max_seconds:, clock:)
    @io = io
    @clock = clock
    @deadline = clock.now + max_seconds
  end

  # Answers at most size bytes, or nil at the end of the stream. The budget
  # left is reapplied before every read, so it is the whole run that is
  # bounded rather than each read of it.
  def read(size)
    remaining = remaining_seconds
    raise Expired if remaining <= 0

    io.timeout = remaining
    io.read(size)
  rescue IO::TimeoutError
    raise Expired
  end

  private

  attr_reader :io, :deadline, :clock

  # How much of the budget is left, which is negative once the deadline has
  # passed.
  def remaining_seconds
    deadline - clock.now
  end
end
