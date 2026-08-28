require_relative '../test_base'

class SparePoolTest < TestBase

  test '7Bq2E1', %w(
  | a pool holding no spare for an image answers nothing,
  | which is a miss, and a miss is a test-run creating its own container
  | exactly as one does with no pool behind it at all
  ) do
    set_context

    assert_nil spares.claim(image_name: image_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E2', %w(
  | a spare is handed out once and is then gone from the pool,
  | nothing being recycled: one test-run, one container, so that what one
  | kata left behind is never something the next one inherits
  ) do
    set_context(clock: ClockStub.new(now: 1000.0))
    spares.add(image_name: image_name, container_id: 'c0ffee', expires_at: 1100.0)

    assert_equal 'c0ffee', spares.claim(image_name: image_name)
    assert_nil spares.claim(image_name: image_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E3', %w(
  | spares are held per image, so a claim is never given one made for a
  | different image,
  | which is what lets two katas on one language share a pool while two on
  | different languages share nothing
  ) do
    set_context(clock: ClockStub.new(now: 1000.0))
    perl = 'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a'
    spares.add(image_name: perl, container_id: 'decaf', expires_at: 1100.0)

    assert_nil spares.claim(image_name: image_name)
    assert_equal 'decaf', spares.claim(image_name: perl)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E4', %w(
  | a spare with too little of its sleep left is not handed to a test-run
  | an exec does not outlive its container's PID 1, so a sleep ending under
  | a run kills the kata part way, and the runner then reads a truncated
  | payload and answers the learner faulty for a kata that was fine
  | see docs/profiling/check_spare_sleep_ending_under_a_run.sh
  ) do
    set_context(clock: ClockStub.new(now: 1000.0))
    spares.add(image_name: image_name, container_id: 'nearly_gone', expires_at: 1005.0)

    assert_nil spares.claim(image_name: image_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E5', %w(
  | a spare too near its expiry is dropped rather than left to be considered
  | again, and the one behind it is handed out in its place,
  | so one dying spare costs a claim nothing but the looking
  ) do
    set_context(clock: ClockStub.new(now: 1000.0))
    spares.add(image_name: image_name, container_id: 'nearly_gone', expires_at: 1005.0)
    spares.add(image_name: image_name, container_id: 'fresh', expires_at: 1100.0)

    assert_equal 'fresh', spares.claim(image_name: image_name)
    assert_nil spares.claim(image_name: image_name)
  end
end
