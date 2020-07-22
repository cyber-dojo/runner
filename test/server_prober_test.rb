# frozen_string_literal: true
require_relative 'test_base'

class ServerProberTest < TestBase

  def self.id58_prefix
    '6de'
  end

  # - - - - - - - - - - - - - - - - -

  test '190', %w(
  alive? is true
  ) do
    assert prober.alive?.is_a?(TrueClass)
  end

  # - - - - - - - - - - - - - - - - -

  test '191', %w(
  ready? is true
  ) do
    assert prober.ready?.is_a?(TrueClass)
  end

  # - - - - - - - - - - - - - - - - -

  test '192', %w(
  sha is SHA of git commit which created docker image
  ) do
    assert_sha(prober.sha)
  end

end
