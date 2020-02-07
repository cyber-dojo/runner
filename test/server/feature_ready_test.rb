# frozen_string_literal: true
require_relative 'test_base'

class ReadyTest < TestBase

  def self.id58_prefix
    '872'
  end

  # - - - - - - - - - - - - - - - - -

  test '190',
  %w( its ready ) do
    assert ready?
  end

end
