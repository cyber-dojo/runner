class ClockStub
  # as passed to set_context(clock:), standing in for the machine's clock so
  # that an age can be tested without the suite waiting for one to pass.
  #
  # It does not advance. A test that wants two readings makes two of these,
  # which keeps what the clock says a thing the test states rather than a
  # thing it has to reason about.
  def initialize(now:)
    @now = now
  end

  attr_reader :now
end
