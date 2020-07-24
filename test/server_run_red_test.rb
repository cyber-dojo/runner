# frozen_string_literal: true
require_relative 'test_base'

class ServerRunRedTest < TestBase

  def self.id58_prefix
    'c7A'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'g55', %w( timeout ) do
    @context = Context.new(
      logger:StdoutLoggerSpy.new,
      process:process=ProcessAdapterStub.new
    )
    puller.add(image_name)
    process.spawn { raise Timeout::Error }

    run_cyber_dojo_sh

    assert timed_out?, run_result
  end

  # - - - - - - - - - - - - - - - - -
  
=begin
  class ThreaderStub
    def initialize(stdout='', stderr='')
      @stdout = stdout
      @stderr = stderr
      @n = 0
    end
    def thread
      @n += 1
      if @n === 1
        ThreadStub.new(@stdout)
      end
      if @n === 2
        ThreadStub.new(@stderr)
      end
    end
  end

  class ThreadStub
    def initialize(value)
      @value = value
    end
    attr_reader :value
    def join(_secs)
      self
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'g56', %w( red ) do
    @context = Context.new(
      logger:StdoutLoggerSpy.new,
      process:process=ProcessAdapterStub.new,
      threader:ThreaderStub.new
    )

    puller.add_image(image_name)

    process.spawn { 42 }
    process.detach { ThreadStub.new(0) }
    process.kill {}

    run_cyber_dojo_sh
  end
=end

end
