# frozen_string_literal: true
require_relative '../test_base'

class ProcessSpawnerStubTest < TestBase
  def self.id58_prefix
    'A3r'
  end

  # - - - - - - - - - - - - - - -

  test 'Kb1', %w[
    to stub, make a call without any args and with a block taking args,
    and a subsequent call will ignore its args, and pass the args to the block
  ] do
    stub = ProcessSpawnerStub.new
    stub.spawn do |command, *args|
      message = JSON.pretty_generate({ command: command, args: args })
      raise message.to_s
    end
    error = assert_raises(RuntimeError) { stub.spawn('x', 1, 2) }
    expected = { 'command' => 'x', 'args' => [1, 2] }
    assert_equal expected, JSON.parse!(error.message)
  end
end
