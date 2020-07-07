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
    assert lsp.alive?.is_a?(TrueClass)
    assert prober.alive?.is_a?(TrueClass)
    assert runner.alive?.is_a?(TrueClass)
  end

  # - - - - - - - - - - - - - - - - -

  test '15D', %w(
  ready? is true, useful for k8s readyness probes
  ) do
    assert lsp.ready?.is_a?(TrueClass)
    assert prober.ready?.is_a?(TrueClass)
    assert runner.ready?.is_a?(TrueClass)
  end

  # - - - - - - - - - - - - - - - - -

  test '882', %w(
  sha is SHA of git commit which created docker image
  ) do
    assert_sha(lsp.sha)
    assert_sha(prober.sha)
    assert_sha(runner.sha)
  end

  private

  def lsp
    languages_start_points
  end

  def assert_sha(sha)
    assert sha.is_a?(String), :class
    assert_equal 40, sha.size, :size
    sha.each_char do |ch|
      assert is_lo_hex?(ch), ch
    end
  end

  def is_lo_hex?(ch)
    '0123456789abcdef'.include?(ch)
  end

end
