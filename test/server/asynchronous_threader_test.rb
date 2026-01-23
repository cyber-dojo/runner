# frozen_string_literal: true
require_relative '../test_base'

class AsynchronousThreaderTest < TestBase

  test '3H9Ps3', %w[
    a simple object-wrapper to allow instance-level stubbing
  ] do
    threader = AsynchronousThreader.new
    actual_name = nil
    threaded = threader.thread('stdout-reader') do |name|
      actual_name = name
      42
    end
    joined = threaded.join
    assert_equal 42, joined.value, :value
    assert_equal 'stdout-reader', actual_name, :name
  end
end
