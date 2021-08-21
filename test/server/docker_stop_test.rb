require_relative '../test_base'

class DockerStopTest < TestBase

  def self.id58_prefix
    'c63'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'da5', %w(
  when cyber-dojo.sh times-out
  then docker stop is called
  and a docker-stop call failure is logged
  ) do
    setup_stubs

    docker_stop_called = false
    @sheller.capture(expected_docker_stop_command) { |_command|
      docker_stop_called = true
      ['stdout-stub','Docker-daemon-error',125]
    }

    puller.add(image_name)
    run_cyber_dojo_sh(max_seconds:3)
    assert docker_stop_called

    lines = @logger.logged.lines
    assert_equal 2, lines.size

    assert_json_line(lines[0], {
      id:id58,
      image_name:image_name,
      command:expected_docker_stop_command,
      stdout:'stdout-stub',
      stderr:'Docker-daemon-error',
      status:125
    })

    assert_json_line(lines[1], {
      id:id58,
      image_name:image_name,
      message:'timed_out',
      result:''
    })
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'da6', %w(
  when cyber-dojo.sh times-out
  then docker stop is called
  and a docker-stop call success leaves the log empty
  ) do
    setup_stubs

    docker_stop_called = false
    @sheller.capture(expected_docker_stop_command) { |_command|
      docker_stop_called = true
      ['s1','s2',0]
    }

    puller.add(image_name)
    run_cyber_dojo_sh(max_seconds:3)
    assert docker_stop_called

    lines = @logger.logged.lines
    assert_equal 1, lines.size

    assert_json_line(lines[0], {
      id:id58,
      image_name:image_name,
      message:'timed_out',
      result:''
    })
  end

  private

  def setup_stubs
    set_context(
        logger:@logger=StdoutLoggerSpy.new,
         piper:PipeMakerStub.new(''),
       process:process=ProcessSpawnerStub.new,
       sheller:@sheller=BashShellerStub.new,
      threader:ThreaderStub.new,
        random:RandomHex8Stub.new(hex8_stub)
    )
    process.spawn { |_cmd,_opts| 42 } # pid
    process.detach { |_pid| WaitThreadTimedOutStub.new(57, false) } # status,joined
    process.kill { |_signal,_pid| nil }
  end

  def expected_docker_stop_command
    "docker stop --time 1 cyber_dojo_runner_#{id58}_#{hex8_stub}"
  end

  def hex8_stub
    'a1b2c3d4'
  end

  # - - - - - - - - - - - - - - - - -

  class ThreaderStub
    def thread(name)
      stubs = {
        'stdout-reader' => ThreadValueStub.new(''),
        'stderr-reader' => ThreadValueStub.new(''),
        'docker-stopper' => yield
      }
      stubs[name]
    end
  end

  # - - - - - - - - - - - - - - - - -

  class RandomHex8Stub
    def initialize(stub)
      @stub = stub
    end
    def hex8
      @stub
    end
  end

end
