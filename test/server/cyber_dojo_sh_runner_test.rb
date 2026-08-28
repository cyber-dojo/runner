require_relative '../test_base'
require_code 'cyber_dojo_sh_container_config'
require_code 'cyber_dojo_sh_runner'
require_code 'home_files'
require_code 'externals/docker_socket'

class CyberDojoShRunnerTest < TestBase

  test 'c9Gf10', %w(
  | the run creates a container of its own name
  | from the config that depends on its image alone
  | saying in json what the docker CLI is told in flags
  ) do
    spy = DockerDaemonSpy.new(responses_up_to_the_stream)

    runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    endpoint, config, name = spy.calls[0]
    assert_equal :create_container, endpoint
    assert_equal CyberDojoShContainerConfig.image_config(image_name), config
    assert_equal container_name, name
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf11', %w(
  | the container is started before its exec is made
  | an exec being something only a running container can hold
  | and the exec carries what belongs to this one run
  | and starting the exec is itself what hijacks the stream
  | so there is nothing to attach beforehand and nothing it writes is missed
  | and the container is stopped once the run has its payload, because its own
  | command is a sleep that would otherwise outlive the run
  ) do
    spy = DockerDaemonSpy.new(responses_up_to_the_stream + [[204, '']])

    runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    exec_config = CyberDojoShContainerConfig.exec_config(id58)
    assert_equal [:start_container, 'c0ffee'], spy.calls[1]
    assert_equal [:create_exec, 'c0ffee', exec_config], spy.calls[2]
    assert_equal [:start_exec, 'e5ec1d'], spy.calls[3]
    assert_equal %i[create_container start_container create_exec start_exec stop_container],
                 spy.endpoints
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf12', %w(
  | the tgz is written to the stream, and the writing half is then closed
  | which is what gives the container's [tar -zxf -] its end of file
  | and without which it waits for one that never comes
  ) do
    spy = DockerDaemonSpy.new(responses_up_to_the_stream)

    runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal tgz_in, spy.written
    assert spy.write_half_closed, 'write_half_closed'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf13', %w(
  | the container's two streams are answered separately
  | the payload arriving on stdout, and anything it complained about on stderr
  ) do
    spy = DockerDaemonSpy.new(
      responses_up_to_the_stream,
      frames: [[1, 'the-payload'], [2, 'a warning']]
    )

    result = runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal 'the-payload', result[:stdout]
    assert_equal 'a warning', result[:stderr]
    refute result[:timed_out], 'timed_out'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf14', %w(
  | a container still sending nothing when max_seconds passes is stopped
  | and the run answers timed_out, with no partial payload
  | one second being SIGTERM and then SIGKILL a second later
  | so cyber-dojo.sh's own EXIT trap still gets its chance
  ) do
    spy = DockerDaemonSpy.new(
      responses_up_to_the_stream + [[204, '']],
      stalls: true
    )

    result = runner_using(spy).run(id58, image_name, container_name, 0.1, tgz_in)

    assert result[:timed_out], 'timed_out'
    # Empty rather than absent: there is no payload, and the result keeps the
    # same shape whether the run finished or not.
    assert_equal '', result[:stdout]
    assert_equal '', result[:stderr]
    assert_equal [:stop_container, 'c0ffee', 1], spy.calls.last
    assert_equal %i[create_container start_container create_exec start_exec stop_container],
                 spy.endpoints
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf15', %w(
  | a real run against the real daemon
  | which is the only thing that says the daemon accepts the config,
  | the attach path, and the headers, none of which a stub can judge
  ) do
    http = DockerSocket.new
    set_context(http: http)
    name = "cyber_dojo_runner_#{id58}"

    result = cyber_dojo_sh_runner.run(id58, image_name, name, 10, real_tgz_in("echo hello\n"))

    refute result[:timed_out], 'timed_out'
    files = TGZ.files(result[:stdout])
    assert_equal '0', files['tmp/status']
    assert_equal "hello\n", files['tmp/stdout']
  ensure
    # AutoRemove disposes of a container that exits, but not of one that never
    # started, and this name is the same on every run. Without this a failure
    # here leaves a container that makes the next run collide with it.
    # force=true is this test's own cleanup, so it goes straight to the
    # transport rather than putting a force nothing in the runner wants on
    # DockerDaemon.
    http.request('DELETE', "/containers/#{name}?force=true")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf16', %w(
  | a create the daemon refuses raises, naming what it said
  | rather than carrying on with no container id
  | eg a name already taken by a container that never started
  | and nothing is stopped, a refused create having made no container to stop
  ) do
    conflict = '{"message":"Conflict. The container name is already in use"}'
    spy = DockerDaemonSpy.new([[409, conflict]])

    error = assert_raises(CyberDojoShRunner::DaemonRefused) do
      runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)
    end

    assert_includes error.message, '409'
    assert_includes error.message, 'already in use'
    assert_equal %i[create_container], spy.endpoints
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf20', %w(
  | an exec create the daemon refuses raises, naming what it said
  | rather than carrying on with no exec id and starting nothing
  | eg a container that stopped between being started and being exec'd into
  ) do
    conflict = '{"message":"Container c0ffee is not running"}'
    spy = DockerDaemonSpy.new([[201, '{"Id":"c0ffee"}'], [204, ''], [409, conflict]])

    error = assert_raises(CyberDojoShRunner::DaemonRefused) do
      runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)
    end

    assert_includes error.message, '409'
    assert_includes error.message, 'is not running'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf21', %w(
  | a run refused partway still disposes of the container it made
  | the container having been created and started before the refusal
  | so nothing else stops it and it would sleep out its Cmd holding memory
  ) do
    conflict = '{"message":"Container c0ffee is not running"}'
    spy = DockerDaemonSpy.new(
      [[201, '{"Id":"c0ffee"}'], [204, ''], [409, conflict], [204, '']]
    )

    assert_raises(CyberDojoShRunner::DaemonRefused) do
      runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)
    end

    assert_equal [:stop_container, 'c0ffee', 1], spy.calls.last
    assert_equal %i[create_container start_container create_exec stop_container],
                 spy.endpoints
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf22', %w(
  | the container is stopped on a thread, so that the run answers the learner
  | without waiting for a teardown they cannot see
  | the stop still happens, and still last, but off the path whose length is
  | the whole reason for holding containers ready
  ) do
    threader = ThreaderSynchronous.new
    spy = DockerDaemonSpy.new(responses_up_to_the_stream + [[204, '']])
    set_context(docker: spy, threader: threader)

    cyber_dojo_sh_runner.run(id58, image_name, container_name, max_seconds, tgz_in)

    assert threader.called, 'threader'
    assert_equal [:stop_container, 'c0ffee', 1], spy.calls.last
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf17', %w(
  | a real fork bomb against the real daemon leaves no container behind
  | however the bomb ends, the bomb saturating PidsLimit so that send_tgz
  | cannot fork the find, file, tar and gzip its EXIT trap needs
  ) do
    http = DockerSocket.new
    set_context(http: http)
    name = "cyber_dojo_runner_#{id58}"

    # Nothing about the result is asserted here, and adding an assert on it
    # makes this test flaky rather than stricter. A bomb has two ends, and
    # which one it takes is a race:
    #   - the fork failures leave PID 1 stuck, so the deadline expires and the
    #     run answers timed_out with empty strings
    #   - the fork failures take PID 1 down with them, so the attach stream
    #     ends and the run answers timed_out false, carrying whatever complete
    #     frames arrived, which need not be nothing
    # Pinning the deadline is c9Gf18's job, with a kata that cannot end early.
    # What keeps a payload that arrives whole but does not inflate out of the
    # browser is runner.rb answering faulty, which is pinned by c7Dd54 in
    # test/server/run_faulty_gzip_error_test.rb
    cyber_dojo_sh_runner.run(id58, image_name, name, 2, real_tgz_in(FORK_BOMB))

    assert gone?(http, name), "#{name} was left behind"
  ensure
    http.request('DELETE', "/containers/#{name}?force=true")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf18', %w(
  | a real container that sends nothing before the deadline times out
  | and is stopped, with no partial payload to report
  | a sleeping kata rather than a bomb, because a sleep cannot end early:
  | it sends nothing and nothing kills its PID 1
  ) do
    http = DockerSocket.new
    set_context(http: http)
    name = "cyber_dojo_runner_#{id58}"

    result = cyber_dojo_sh_runner.run(id58, image_name, name, 1, real_tgz_in("sleep 30\n"))

    assert result[:timed_out], 'timed_out'
    assert_equal '', result[:stdout]
    assert gone?(http, name), "#{name} was left behind"
  ensure
    http.request('DELETE', "/containers/#{name}?force=true")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf19', %w(
  | a real run that finishes disposes of its container
  | which nothing else does: the container's own command is a sleep, so it
  | outlives the exec that did the work and AutoRemove has nothing to react to
  | and a run that left it behind would hold one container per test-run
  | for the rest of that sleep, which scales with traffic and not with any cap
  ) do
    http = DockerSocket.new
    set_context(http: http)
    name = "cyber_dojo_runner_#{id58}"

    result = cyber_dojo_sh_runner.run(id58, image_name, name, 10, real_tgz_in("echo hello\n"))

    refute result[:timed_out], 'timed_out'
    assert gone?(http, name), "#{name} was left behind"
  ensure
    http.request('DELETE', "/containers/#{name}?force=true")
  end

  private

  # The runner, built the way runner.rb builds it, from the context the test
  # set up. What it talks to is chosen in set_context and never here.
  def cyber_dojo_sh_runner
    CyberDojoShRunner.new(context)
  end

  # The same, for a test that stands a daemon in rather than using the real
  # one, so that the standing-in and the building stay one step.
  #
  # Threading is synchronous here. The stop runs on a thread, and a test that
  # pins what the daemon was asked cannot be left racing it. c9Gf22 is the one
  # test that cares the thread exists, and it wires its own.
  def runner_using(daemon)
    set_context(docker: daemon, threader: ThreaderSynchronous.new)
    cyber_dojo_sh_runner
  end

  # test/client/robustness_test.rb 1B5CD6
  FORK_BOMB = <<~SHELL.freeze
    bomb()
    {
      echo "bomb"
      bomb | bomb &
    }
    bomb
  SHELL

  # AutoRemove disposes of the container once it has exited, which is not the
  # instant the stop returns.
  # A single answer at the end says whether the container went, however many
  # polls it took, so the giving-up path is the same path as the going one.
  # Inspecting a container by name is no part of what the runner does, so this
  # asks the transport rather than DockerDaemon.
  def gone?(http, name)
    code = nil
    20.times do
      code, _body = http.request('GET', "/containers/#{name}/json")
      break if code == 404

      sleep 0.2
    end
    code == 404
  end

  include HomeFiles

  # What runner.rb sends in: the kata's files under the sandbox dir, plus the
  # script that runs them and installs the send_tgz EXIT trap.
  def real_tgz_in(cyber_dojo_sh)
    files = Sandbox.in({ 'cyber-dojo.sh' => cyber_dojo_sh })
    TGZ.of(files.merge(home_files(Sandbox::DIR, 50 * 1024)))
  end

  # What the daemon answers to the three calls a run makes before it has a
  # stream: the container created, the container started, and an exec made in
  # it. A test that gets as far as the stream needs all three.
  def responses_up_to_the_stream
    [[201, '{"Id":"c0ffee"}'], [204, ''], [201, '{"Id":"e5ec1d"}']]
  end

  def container_name
    'cyber_dojo_runner_stub'
  end

  def tgz_in
    'would-be-a-tgz'
  end
end
