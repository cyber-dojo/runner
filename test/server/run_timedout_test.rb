# frozen_string_literal: true
require_relative '../test_base'
require_code 'capture3_with_timeout'

class RunTimedOutTest < TestBase

  def self.id58_prefix
    'c7A'
  end

  include Capture3WithTimeout

  # - - - - - - - - - - - - - - - - - - - - -

  test 'g55', %w(
  timeout in wait_thread.value
  results in timed_out status
  ) do
    stdout_tgz = 'would-be-proper-tgz-data'
    set_context(
       logger:StdoutLoggerSpy.new,
        piper:PiperStub.new(stdout_tgz),
      process:process=ProcessSpawnerStub.new
    )
    status = 57
    puller.add(image_name)
    process.spawn { 42 } # pid
    process.detach { ThreadTimedOutStub.new(status) }
    process.kill { nil }

    yielded_to_block = false
    result = capture3_with_timeout(@context, command=nil, max_seconds=3, tgz_in=nil) {
      yielded_to_block = true
    }

    assert yielded_to_block
    expected = {
      timed_out:true,
      stdout:stdout_tgz,
      stderr:'',
      status:status
    }
    assert_equal expected, result

    run = run_cyber_dojo_sh(max_seconds:3)
    expected = {
      'outcome' => 'timed_out',
      'stdout' => {'content'=>'', 'truncated'=>false},
      'stderr' => {'content'=>'', 'truncated'=>false},
      'status' => Runner::STATUS[:timed_out].to_s,
      "log" => {
        :timed_out => true,
        :status => status,
        :stdout => '',
        :stderr => ''
      },
      "created"=>{}, "deleted"=>[], "changed"=>{}
    }
    assert_equal expected, run

  end

  # - - - - - - - - - - - - - - - - - - - - -

  private

  class ThreadTimedOutStub
    def initialize(status)
      @n = 0
      @stubs = {
        1 => lambda { raise Timeout::Error },
        2 => lambda { status }
      }
    end
    def value
      @n += 1
      @stubs[@n].call
    end
    def join(_seconds)
      self
    end
  end

end
