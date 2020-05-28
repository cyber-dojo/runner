# frozen_string_literal: true
require_relative 'test_base'
require_source 'prober'

class FeatureProberTest < TestBase

  def self.id58_prefix
    '6de'
  end

  # - - - - - - - - - - - - - - - - -

  test '190', %w(
  alive? is true, useful for k8s liveness probes
  ) do
    assert alive?
  end

  # - - - - - - - - - - - - - - - - -

  test '191', %w(
  ready? is true, useful for k8s readyness probes
  ) do
    assert ready?
  end

  # - - - - - - - - - - - - - - - - -

  test '192', %w(
  sha is SHA of git commit which created docker image
  ) do
    assert_sha(sha)
  end

  private

  def prober
    Prober.new(externals, {})
  end

  def alive?
    prober.alive?['alive?']
  end

  def ready?
    prober.ready?['ready?']
  end

  def sha
    prober.sha['sha']
  end

end
