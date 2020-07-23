# frozen_string_literal: true
require_relative 'test_base'

class ServerProcessAdapterTest < TestBase

  def self.id58_prefix
    'h9U'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'S3e', %w(
  a simple object-wrapper to allow instance-level stubbing
  ) do
    processor = ProcessAdapter.new
    pid = processor.spawn('sleep 10', {})
    processor.detach(pid)
    processor.kill(:TERM, pid)
  end

end
