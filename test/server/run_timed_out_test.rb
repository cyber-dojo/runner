# frozen_string_literal: true
require_relative '../test_base'

class RunTimedOutTest < TestBase

  def self.id58_prefix
    'c7A'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'g55', %w( timeout ) do
    stdout_tgz = TGZ.of({'stderr' => 'any'})
    set_context(
       logger:StdoutLoggerSpy.new,
        piper:PiperStub.new(stdout_tgz),
      process:process=ProcessSpawnerStub.new
    )
    puller.add(image_name)
    process.spawn { 42 }
    process.detach { ThreadTimedOutStub.new }
    process.kill { nil }

    run_cyber_dojo_sh(max_seconds:3)

    assert timed_out?, run_result
    assert_equal Runner::STATUS[:timed_out], status.to_i
    assert_equal '', stdout
    assert_equal '', stderr
  end

  private

  class ThreadTimedOutStub
    def initialize
      @n = 0
      @stubs = {
        1 => lambda { raise Timeout::Error },
        2 => lambda { 137 }
      }
    end
    def value
      @n += 1
      @stubs[@n].call
    end
    def join(_seconds)
      nil
    end
  end

end
