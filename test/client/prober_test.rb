# frozen_string_literal: true
require_relative '../test_base'

class ProberTest < TestBase

  def self.id58_prefix
    '5de'
  end

  # - - - - - - - - - - - - - - - - -

  test '190', %w(
  alive? is true
  ) do
    set_context
    assert runner.alive?.is_a?(TrueClass)
  end

  # - - - - - - - - - - - - - - - - -

  test '191', %w(
  ready? is true
  ) do
    set_context
    assert runner.ready?.is_a?(TrueClass)
  end

  # - - - - - - - - - - - - - - - - -

  test '192', %w(
  sha is SHA of git commit which created docker image
  ) do
    set_context
    assert_sha(runner.sha)
  end

end
