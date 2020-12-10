# frozen_string_literal: true

class PiperStub

  def initialize(stdout_tgz)
    @stdout_tgz = stdout_tgz
    @n = 0
  end

  def io
    Struct.new(:in, :out).new(
      Class.new do
        def initialize(read); @read = read; end
        def binmode; end
        def read; @read; end
        def close; end
      end.new(stdout_tgz),
      Class.new do
        def sync=(_bool); end
        def binmode; end
        def write(_tgz_in); end
        def closed?; true; end
        def close; end
      end.new
    )
  end

  private

  def stdout_tgz
    @n += 1
    if @n === 2
      @stdout_tgz # 2nd io is for stdout
    else
      '' # 1st is for stdin, 3rd is for stderr
    end
  end

end
