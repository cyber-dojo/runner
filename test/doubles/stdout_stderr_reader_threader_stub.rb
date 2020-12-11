# frozen_string_literal: true
require_relative 'thread_value_stub'

class StdoutStderrReaderThreaderStub

  def initialize(stdout_tgz, stderr)
    @stubs = {
      'reads-stdout' => ThreadValueStub.new(stdout_tgz),
      'reads-stderr' => ThreadValueStub.new(stderr)
    }
  end

  def thread(name)
    @stubs[name]
  end

end
