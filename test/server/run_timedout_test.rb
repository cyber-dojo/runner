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
  and any captured stdout/stderr are not part of run_cyber_dojo_sh result
  ) do
    stdout_tgz = 'would-be-proper-tgz-data'
    set_context(
       logger:StdoutLoggerSpy.new,
        piper:PiperStub.new(stdout_tgz),
      process:process=ProcessSpawnerStub.new
    )

    puller.add(image_name)

    pid = 42
    process.spawn { |_cmd,_opts| pid }

    detach_args = []
    status = 57
    process.detach { |pid|
      detach_args << pid
      ThreadTimedOutStub.new(status)
    }

    kill_args = []
    process.kill { |signal,pid|
      kill_args << [signal,pid]
      nil
    }

    yielded_to_block = false

    result = capture3_with_timeout(@context, command=nil, max_seconds=1, tgz_in=nil) {
      yielded_to_block = true
    }

    assert_equal [pid], detach_args
    assert_equal [[:TERM,-pid],[:KILL,-pid]], kill_args

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

  test 'g56', %(
  when process.spawn() fails to respond within the timeout period
  thats also a timeout
  and nothing is captured from the io pipes
  and no process.detch() or process.kill() calls are made
  ) do
    stdout_tgz = 'tweedle-dee'
    set_context(
       logger:StdoutLoggerSpy.new,
        piper:PiperStub.new(stdout_tgz),
      process:process=ProcessSpawnerStub.new
    )
    puller.add(image_name)
    process.spawn { sleep 10; }

    yielded_to_block = false
    result = capture3_with_timeout(@context, command=nil, max_seconds=1, tgz_in=nil) {
      yielded_to_block = true
    }

    assert yielded_to_block
    expected = {
      timed_out:true,
      stdout:nil,
      stderr:nil,
      status:nil
    }
    assert_equal expected, result
  end

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
      # wait_thread.kill(:TERM, -pid) was issued
      # but the thread did not exit after _seconds passed.
      nil
    end
  end

end
