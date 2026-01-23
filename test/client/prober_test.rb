# frozen_string_literal: true
require_relative '../test_base'

class ProberTest < TestBase

  test '5de190', %w(
  | alive? is true
  ) do
    set_context
    assert runner.alive?.is_a?(TrueClass)
  end

  # - - - - - - - - - - - - - - - - -

  test '5de191', %w(
  | ready? is true
  ) do
    set_context
    assert runner.ready?.is_a?(TrueClass)
  end

  # - - - - - - - - - - - - - - - - -

  test '5de192', %w(
  | sha is SHA of git commit which created docker image
  ) do
    set_context
    assert_sha(runner.sha)
  end
end
