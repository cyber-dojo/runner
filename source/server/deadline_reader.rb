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

  def initialize(io, deadline)
    @io = io
    @deadline = deadline
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

  attr_reader :io, :deadline

  def remaining_seconds
    deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
