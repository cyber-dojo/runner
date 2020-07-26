# frozen_string_literal: true

class PiperStub

  def initialize(stdout_tgz)
    @stdout_tgz = stdout_tgz
  end

  def io
    Struct.new(:in, :out).new(
      Class.new do
        def initialize(read); @read = read; end
        def binmode; end
        def read; @read; end
        def close; end
      end.new(@stdout_tgz),
      Class.new do
        def sync=(_); end
        def binmode; end
        def write(_); end
        def closed?; true; end
        def close; end
      end.new
    )
  end
  
end
