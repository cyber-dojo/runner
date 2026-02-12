require_relative 'thread_value_stub'

class StdoutStderrReaderThreaderStub
  def initialize(stdout_tgz, stderr)
    @stubs = {
      'stdout-reader' => ThreadValueStub.new(stdout_tgz),
      'stderr-reader' => ThreadValueStub.new(stderr)
    }
  end

  def thread(name)
    @stubs[name]
  end
end
