# frozen_string_literal: true
require_relative 'test_base'

class Ready < TestBase

  def self.id58_prefix
    'A86'
  end

  # - - - - - - - - - - - - - - - - -

  test '15D', 'its ready' do
    assert runner.ready?['ready?'].is_a?(TrueClass)
  end

end
