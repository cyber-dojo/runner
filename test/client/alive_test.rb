# frozen_string_literal: true
require_relative 'test_base'

class AliveTest < TestBase

  def self.id58_prefix
    '74C'
  end

  # - - - - - - - - - - - - - - - - -

  test 'CA2', 'its alive' do
    assert runner.alive?['alive?'].is_a?(TrueClass)
  end

end
