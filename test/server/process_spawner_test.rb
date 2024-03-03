# frozen_string_literal: true
require_relative '../test_base'

class ProcessSpawnerTest < TestBase
  def self.id58_prefix
    'h9U'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'S3e', %w[
    a simple object-wrapper to allow instance-level stubbing
  ] do
    r, w = IO.pipe
    processor = ProcessSpawner.new
    pid = processor.spawn('printf hello', out: w)
    w.close
    echoed = r.read
    processor.detach(pid)
    processor.kill(:TERM, pid)
    assert_equal 'hello', echoed
  end
end
