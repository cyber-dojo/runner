require_relative '../test_base'

class MonotonicClockTest < TestBase

  test 'Dm5x40', %w[
  | context.clock answers seconds as a Float, and advances by at least a
  | slept interval, which is what says it reads a clock rather than
  | answering a constant
  | at least, rather than exactly, because how long a sleep really takes is
  | the scheduler's business and not this test's
  ] do
    set_context
    # Short enough not to slow the suite, long enough to exceed any clock's
    # resolution. The sleep and the assertion have to name the same number.
    slept_seconds = 0.01

    before = clock.now
    sleep(slept_seconds)
    after = clock.now

    assert before.is_a?(Float), before.class.name
    assert_operator(after - before, :>=, slept_seconds)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Dm5x41', %w[
  | the clock is not the wall clock, which is the whole reason for it
  | the wall clock counts from 1970 and this counts from the machine booting,
  | so it reads smaller by decades
  | an age measured against the wall clock could be made negative by ntp
  | stepping it back, and a spare would then look newer than it is
  ] do
    set_context

    assert_operator clock.now, :<, Time.now.to_f
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Dm5x42', %w[
  | a test can stand in for the clock, which is what will let an age be
  | tested without the suite waiting for one to pass
  ] do
    set_context(clock: ClockStub.new(now: 41.0))

    assert_equal 41.0, clock.now
  end
end
