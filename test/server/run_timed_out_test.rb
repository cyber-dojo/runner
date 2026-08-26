require_relative '../test_base'
require_code 'capture3_with_timeout'

class RunTimedOutTest < TestBase

  test 'c7Ag55', %w(
  | timeout in wait_thread.value
  | results in timed_out status
  | and the container is stopped, which is what makes the docker CLI exit
  | and any captured stdout/stderr are not part of run_cyber_dojo_sh result
  ) do
    stdout_tgz = 'would-be-proper-tgz-data'
    set_context(
      logger: StdoutLoggerSpy.new,
      piper: PipeMakerStub.new(stdout_tgz),
      process: process = ProcessSpawnerStub.new,
      sheller: sheller = BashShellerStub.new,
      random: RandomHex8Stub.new(hex8_stub)
    )
    sheller.capture(docker_stop_command(CONTAINER_NAME)) { ['', '', 0] }

    pid = 42
    process.spawn { |_cmd, _opts| pid }

    detach_args = []
    status = 57
    process.detach do |pid|
      detach_args << pid
      WaitThreadTimedOutStub.new(status)
    end

    # inner timed-out
    result = capture3_with_timeout

    assert_equal [pid], detach_args
    sheller.teardown # nothing left unconsumed proves the docker stop was made

    expected = {
      timed_out: true,
      stdout: stdout_tgz,
      stderr: '',
      status: status,
      docker_stop: {
        command: docker_stop_command(CONTAINER_NAME),
        stdout: '',
        stderr: '',
        status: 0
      }
    }
    assert_equal expected, result

    # outer result of run_cyber_dojo_sh
    expected = {
      'outcome' => 'timed_out',
      'stdout' => { 'content' => '', 'truncated' => false },
      'stderr' => { 'content' => '', 'truncated' => false },
      'status' => Runner::STATUS[:timed_out].to_s,
      'log' => {
        timed_out: true,
        status: status,
        stdout: '',
        stderr: ''
      },
      'created' => {},
      'changed' => {}
    }
    sheller.capture(docker_stop_command("cyber_dojo_runner_#{id58}_#{hex8_stub}")) { ['', '', 0] }
    puller.add(image_name)
    run = run_cyber_dojo_sh(max_seconds: 3)
    assert_equal expected, run
    sheller.teardown
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c7Ag56', %w[
    in capture3_with_timeout()
    when process.spawn() fails to respond within the timeout period
    thats also a timeout
    and no process.detach() call is made
    and no container is stopped, because there is none to stop
  ] do
    stdout_tgz = 'tweedle-dee'
    set_context(
      logger: StdoutLoggerSpy.new,
      piper: PipeMakerStub.new(stdout_tgz),
      process: process = ProcessSpawnerStub.new
    )

    process.spawn { sleep 10 }

    result = capture3_with_timeout

    expected = {
      timed_out: true,
      stdout: stdout_tgz,
      stderr: '',
      status: nil
    }
    assert_equal expected, result
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c7Ag58', %w(
  | in capture3_with_timeout()
  | when there is no timeout
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      piper: PipeMakerStub.new('mad-hatter', closed: false),
      process: process = ProcessSpawnerStub.new
    )

    pid = 44
    process.spawn { |_cmd, _opts| pid }

    detach_args = []
    status = 59
    process.detach do |pid|
      detach_args << pid
      WaitThreadCompletedStub.new(status)
    end

    result = capture3_with_timeout

    assert_equal [pid], detach_args

    expected = {
      timed_out: false,
      stdout: 'mad-hatter',
      stderr: '',
      status: status
    }
    assert_equal expected, result
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c7Ag59', %w(
  | in capture3_with_timeout()
  | when the docker stop does not make the docker CLI exit
  | then the CLI process is killed
  | so that the runner does not wait for ever
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      piper: PipeMakerStub.new('dormouse'),
      process: process = ProcessSpawnerStub.new,
      sheller: sheller = BashShellerStub.new,
      random: RandomHex8Stub.new(hex8_stub)
    )
    sheller.capture(docker_stop_command(CONTAINER_NAME)) { ['', '', 0] }

    pid = 45
    process.spawn { |_cmd, _opts| pid }
    process.detach { |_pid| WaitThreadTimedOutStub.new(61, joined: false) }

    kill_args = []
    process.kill do |signal, pid|
      kill_args << [signal, pid]
      nil
    end

    capture3_with_timeout

    assert_equal [[:KILL, pid]], kill_args
    sheller.teardown
  end

  private

  CONTAINER_NAME = 'cyber_dojo_runner_stub'

  def capture3_with_timeout
    runner = Capture3WithTimeout.new(@context, CONTAINER_NAME)
    runner.run(command = nil, max_seconds = 1, tgz_in = nil)
  end

  def docker_stop_command(container_name)
    "docker stop --time 1 #{container_name}"
  end

  def hex8_stub
    'a1b2c3d4'
  end
end
