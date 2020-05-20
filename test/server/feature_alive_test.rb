# frozen_string_literal: true
require_relative 'test_base'

class AliveTest < TestBase

  def self.id58_prefix
    '6de'
  end

  # - - - - - - - - - - - - - - - - -

  test '190', %w(
  alive? is true, useful for k8s liveness probes
  ) do
    assert alive?
  end

end
