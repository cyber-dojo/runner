# frozen_string_literal: true
require_relative 'test_base'

class AliveTest < TestBase

  def self.id58_prefix
    '74C'
  end

  # - - - - - - - - - - - - - - - - -

  test 'CA2', %w(
  alive? is true, useful for k8s liveness probes
  ) do
    assert prober.alive?.is_a?(TrueClass)
  end

  # - - - - - - - - - - - - - - - - -

  test '15D', %w(
  ready? is true, useful for k8s readyness probes
  ) do
    assert prober.ready?.is_a?(TrueClass)
  end

  # - - - - - - - - - - - - - - - - -

  test '882', %w(
  sha is SHA of git commit which created docker image
  ) do
    sha = prober.sha
    assert sha.is_a?(String), :class
    assert_equal 40, sha.size, :size
    sha.each_char.all?{ |ch|
      assert is_lo_hex?(ch), ch
    }
  end

  private

  def is_lo_hex?(ch)
    '0123456789abcdef'.include?(ch)
  end
  
end
