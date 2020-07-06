# frozen_string_literal: true
require_relative 'test_base'

class ProcessStubTest < TestBase

  def self.id58_prefix
    'A3r'
  end

  # - - - - - - - - - - - - - - -

  test 'Kb1',
  %w( use with a block to supply the stub, use without a block gets the stub ) do
    stub = ProcessStub.new
    stub.spawn { 42 }
    assert_equal 42, stub.spawn
  end

end
