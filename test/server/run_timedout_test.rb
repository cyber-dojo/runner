# frozen_string_literal: true
require_relative '../test_base'
require_code 'capture3_with_timeout'

class RunTimedOutTest < TestBase

  def self.id58_prefix
    'c7A'
  end

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

    pid = 42
    process.spawn { |_cmd,_opts| pid }

    detach_args = []
    command_status = 57
    join_result = nil # wait_thread.join(seconds)==nil means process.kill(:TERM, -pid) failed
    process.detach { |pid|
      detach_args << pid
      WaitThreadTimedOutStub.new(command_status,join_result)
    }

    kill_args = []
    process.kill { |signal,pid|
      kill_args << [signal,pid]
      nil
    }

    yielded_to_block = false

    # inner timed-out
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
      status:command_status
    }
    assert_equal expected, result

    # outer result of run_cyber_dojo_sh
    expected = {
      'outcome' => 'timed_out',
      'stdout' => {'content'=>'', 'truncated'=>false},
      'stderr' => {'content'=>'', 'truncated'=>false},
      'status' => Runner::STATUS[:timed_out].to_s,
      "log" => {
        :timed_out => true,
        :status => command_status,
        :stdout => '',
        :stderr => ''
      },
      "created"=>{}, "deleted"=>[], "changed"=>{}
    }
    puller.add(image_name)
    run = run_cyber_dojo_sh(max_seconds:3)
    assert_equal expected, run
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'g56', %(
  in capture3_with_timeout()
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

  # - - - - - - - - - - - - - - - - - - - - -

  test 'g57', %w(
  in capture3_with_timeout()
  when process.kill(:TERM,-pid) completes
  then wait_thread.join() returns non nil
  and the process.kill(:KILL, -pid) call is not made
  ) do
    set_context(
       logger:StdoutLoggerSpy.new,
        piper:PiperStub.new('alice'),
      process:process=ProcessSpawnerStub.new
    )

    pid = 43
    process.spawn { |_cmd,_opts| pid }

    detach_args = []
    command_status = 59
    join_result = Object.new # wait_thread.join(seconds)!=nil means process.kill(:TERM, -pid) succeeded
    process.detach { |pid|
      detach_args << pid
      WaitThreadTimedOutStub.new(command_status,join_result)
    }

    kill_args = []
    process.kill { |signal,pid|
      kill_args << [signal,pid]
      nil
    }

    yielded_to_block = false

    capture3_with_timeout(@context, command=nil, max_seconds=1, tgz_in=nil) {
      yielded_to_block = true
    }

    assert yielded_to_block
    assert_equal [pid], detach_args
    assert_equal [[:TERM,-pid]], kill_args
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'g58', %w(
  in capture3_with_timeout()
  when there is no timeout
  ) do
    set_context(
       logger:StdoutLoggerSpy.new,
        piper:PiperStub.new('mad-hatter', false),
      process:process=ProcessSpawnerStub.new
    )

    pid = 44
    process.spawn { |_cmd,_opts| pid }

    detach_args = []
    command_status = 59
    process.detach { |pid|
      detach_args << pid
      WaitThreadCompletedStub.new(command_status)
    }

    result = capture3_with_timeout(@context, command=nil, max_seconds=1, tgz_in=nil) {}

    assert_equal [pid], detach_args

    expected = {
      timed_out:false,
      stdout:'mad-hatter',
      stderr:'',
      status:command_status
    }
    assert_equal expected, result
  end

  private

  def capture3_with_timeout(context, command, max_seconds, tgz_in, &block)
    runner = Capture3WithTimeout.new(context)
    runner.run(max_seconds, command, tgz_in, &block)
  end

  class WaitThreadTimedOutStub
    # as returned from process.detach() call
    def initialize(command_result,join_result)
      @n = 0
      @value_stubs = {
        1 => lambda { raise Timeout::Error }, # .value in main-block
        2 => lambda { command_result }        # .value in ensure block
      }
      @join_result = join_result
    end
    def value
      @n += 1
      @value_stubs[@n].call
    end
    def join(_seconds)
      @join_result
    end
  end

  # - - - - - - - - - - - - - - - - - - - -

  class WaitThreadCompletedStub
    def initialize(command_result)
      @command_result = command_result
    end
    def value
      @command_result
    end
  end

end
