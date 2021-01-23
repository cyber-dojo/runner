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
        piper:PipeMakerStub.new(stdout_tgz),
      process:process=ProcessSpawnerStub.new
    )

    pid = 42
    process.spawn { |_cmd,_opts| pid }

    detach_args = []
    status = 57
    joined = false
    process.detach { |pid|
      detach_args << pid
      WaitThreadTimedOutStub.new(status, joined)
    }

    kill_args = []
    process.kill { |signal,pid|
      kill_args << [signal,pid]
      nil
    }

    # inner timed-out
    result = capture3_with_timeout

    assert_equal [pid], detach_args
    assert_equal [[:TERM,-pid],[:KILL,-pid]], kill_args

    expected = {
      timed_out:true,
      stdout:stdout_tgz,
      stderr:'',
      status:status
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
        :status => status,
        :stdout => '',
        :stderr => ''
      },
      "created"=>{},
      "changed"=>{}
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
  and no process.detch() call is made
  and no process.kill() call is made
  ) do
    stdout_tgz = 'tweedle-dee'
    set_context(
       logger:StdoutLoggerSpy.new,
        piper:PipeMakerStub.new(stdout_tgz),
      process:process=ProcessSpawnerStub.new
    )

    process.spawn { sleep 10; }

    result = capture3_with_timeout

    expected = {
      timed_out:true,
      stdout:stdout_tgz,
      stderr:'',
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
        piper:PipeMakerStub.new('alice'),
      process:process=ProcessSpawnerStub.new
    )

    pid = 43
    process.spawn { |_cmd,_opts| pid }

    detach_args = []
    status = 59
    joined = true
    process.detach { |pid|
      detach_args << pid
      WaitThreadTimedOutStub.new(status, joined)
    }

    kill_args = []
    process.kill { |signal,pid|
      kill_args << [signal,pid]
      nil
    }

    capture3_with_timeout

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
        piper:PipeMakerStub.new('mad-hatter', false),
      process:process=ProcessSpawnerStub.new
    )

    pid = 44
    process.spawn { |_cmd,_opts| pid }

    detach_args = []
    status = 59
    process.detach { |pid|
      detach_args << pid
      WaitThreadCompletedStub.new(status)
    }

    result = capture3_with_timeout

    assert_equal [pid], detach_args

    expected = {
      timed_out:false,
      stdout:'mad-hatter',
      stderr:'',
      status:status
    }
    assert_equal expected, result
  end

  private

  def capture3_with_timeout(&block)
    runner = Capture3WithTimeout.new(@context)
    runner.run(command=nil, max_seconds=1, tgz_in=nil)
  end

end
