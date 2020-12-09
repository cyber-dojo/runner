# frozen_string_literal: true
require_relative '../test_base'

module Server
  class ThreaderAsynchronousTest < TestBase

    def self.id58_prefix
      '3H9'
    end

    # - - - - - - - - - - - - - - - - - - - - -

    test 'Ps3', %w(
    a simple object-wrapper to allow instance-level stubbing
    ) do
      threader = ThreaderAsynchronous.new
      threaded = threader.thread { 42 }
      joined = threaded.join
      assert_equal 42, joined.value
    end

  end
end