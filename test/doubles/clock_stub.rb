class ClockStub
  # as passed to set_context(clock:), standing in for the machine's clock so
  # that a duration, or an age, can be tested without the suite waiting for
  # one to pass.
  #
  # It advances by the same amount on every read, which is what a clock does.
  # A test states the interval rather than a list of readings, so it says the
  # one thing it cares about, and code that reads the clock more often than
  # the test is interested in neither runs out of readings nor sees time
  # stand still.
  def initialize(from:, advancing_by:)
    @next = from
    @advancing_by = advancing_by
  end

  def now
    reading = @next
    @next += @advancing_by
    reading
  end
end
