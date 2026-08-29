require_relative '../test_base'
require_code 'cyber_dojo_sh_container_config'
require_code 'cyber_dojo_sh_runner'
require_code 'home_files'
require_code 'externals/docker_socket'

class CyberDojoShRunnerTest < TestBase

  test 'c9Gf10', %w(
  | The pool holds no spare, so the run makes its own container.
  | That create is the run's first call to the daemon.
  | The container is named for the run.
  | Its config comes from the image_name alone.
  | Nothing about this particular run reaches the create.
  ) do
    spy = DockerDaemonSpy.new(responses_up_to_the_stream + [[204, '']] + refill_finds_a_full_node)

    runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    endpoint, config, name = spy.calls[0]
    assert_equal :create_container, endpoint
    assert_equal CyberDojoShContainerConfig.image_config(image_name), config
    assert_equal container_name, name
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf11', %w(
  | The pool holds no spare, so the run makes its own container.
  | The container is started, and then an exec is made in it.
  | Only a running container can hold an exec.
  | The exec's config holds the command that runs the kata, and the kata id.
  | A spare and a container made here are both created from image_config.
  | So the exec is where both of those reach the container.
  | Starting the exec is what hijacks the stream.
  | So there is no attach call before it.
  | The container is stopped once the run has its payload.
  | Its own command is a sleep, which outlives the exec that did the work.
  ) do
    spy = DockerDaemonSpy.new(responses_up_to_the_stream + [[204, '']] + refill_finds_a_full_node)

    runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    exec_config = CyberDojoShContainerConfig.exec_config(id58)
    assert_equal [:start_container, 'c0ffee'], spy.calls[1]
    assert_equal [:create_exec, 'c0ffee', exec_config], spy.calls[2]
    assert_equal [:start_exec, 'e5ec1d'], spy.calls[3]
    assert_equal spy.endpoints_for(:made_a_container, :execd_the_kata,
                                   :stopped_the_container, :spare_pool_is_full),
                 spy.endpoints
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf12', %w(
  | The tgz is written to the stream.
  | The writing half is then closed.
  | That close is what gives the container's [tar -zxf -] its end of file.
  ) do
    spy = DockerDaemonSpy.new(responses_up_to_the_stream + [[204, '']] + refill_finds_a_full_node)

    runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal tgz_in, spy.written
    assert spy.write_half_closed, 'write_half_closed'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf13', %w(
  | The container writes on both of the daemon's two streams.
  | What came on stdout and what came on stderr reach the run separately.
  | The stream ends of its own accord, so the run did not time out.
  ) do
    spy = DockerDaemonSpy.new(
      responses_up_to_the_stream + [[204, '']] + refill_finds_a_full_node,
      frames: [[1, 'the-payload'], [2, 'a warning']]
    )

    result = runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal 'the-payload', result[:stdout]
    assert_equal 'a warning', result[:stderr]
    refute result[:timed_out], 'timed_out'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf14', %w(
  | The container sends nothing, and max_seconds passes.
  | The run answers timed_out.
  | There is no payload, so its stdout and stderr are both empty.
  | The container is stopped, as it is on a run that finishes.
  | The stop sends SIGTERM at once, and SIGKILL one second later.
  | That second is what gives cyber-dojo.sh's EXIT trap its chance to run.
  ) do
    spy = DockerDaemonSpy.new(
      responses_up_to_the_stream + [[204, '']] + refill_finds_a_full_node,
      stalls: true
    )

    result = runner_using(spy).run(id58, image_name, container_name, 0.1, tgz_in)

    assert result[:timed_out], 'timed_out'
    # Empty rather than absent: there is no payload, and the result keeps the
    # same shape whether the run finished or not.
    assert_equal '', result[:stdout]
    assert_equal '', result[:stderr]
    assert_includes spy.calls, [:stop_container, 'c0ffee', 1]
    assert_equal spy.endpoints_for(:made_a_container, :execd_the_kata,
                                   :stopped_the_container, :spare_pool_is_full),
                 spy.endpoints
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf15', %w(
  | The run goes to the real daemon.
  | The kata echoes hello.
  | Its payload holds tmp/status of 0, and tmp/stdout of hello.
  | The run does not time out.
  | A stub cannot judge the config, the attach path, or the headers.
  | Only the daemon can.
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
  | The daemon refuses the create with a 409.
  | That says the container name is already in use.
  | The run raises.
  | The error names the status code, and what the daemon said.
  | Nothing else is asked of the daemon.
  | A refused create made no container, so there is none to stop.
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
  | The container is created and started.
  | The daemon refuses the exec create with a 409.
  | That says the container is not running.
  | A container can stop between being started and being exec'd into.
  | The run raises.
  | The error names the status code, and what the daemon said.
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
  | The container is created and started.
  | The daemon then refuses the exec create.
  | The run raises, and stops the container on its way out.
  | That stop is the last thing asked of the daemon.
  | The container's Cmd is a sleep, so it exits when that sleep ends.
  | AutoRemove acts only on a container that exits.
  | The stop makes it exit now rather than at the end of its sleep.
  ) do
    conflict = '{"message":"Container c0ffee is not running"}'
    spy = DockerDaemonSpy.new(
      [[201, '{"Id":"c0ffee"}'], [204, ''], [409, conflict], [204, '']]
    )

    assert_raises(CyberDojoShRunner::DaemonRefused) do
      runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)
    end

    assert_includes spy.calls, [:stop_container, 'c0ffee', 1]
    assert_equal spy.endpoints_for(:made_a_container, :was_refused_an_exec,
                                   :stopped_the_container),
                 spy.endpoints
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf22', %w(
  | The container is stopped on a thread, so the run answers without waiting.
  | The stop still happens, once the run has its payload.
  | A learner waits for the answer, not for a teardown they never see.
  ) do
    threader = ThreaderSynchronous.new
    spy = DockerDaemonSpy.new(responses_up_to_the_stream + [[204, '']] + refill_finds_a_full_node)
    set_context(docker: spy, threader: threader)

    cyber_dojo_sh_runner.run(id58, image_name, container_name, max_seconds, tgz_in)

    assert threader.called, 'threader'
    assert_includes spy.calls, [:stop_container, 'c0ffee', 1]
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf23', %w(
  | The pool holds a spare for the image_name.
  | The run claims it, and the claim renames it to the run's name.
  | The exec is made in that container.
  | No container is created and none is started.
  | Create and start are what the pool has already done.
  ) do
    # In order: the claim's rename, the exec made in the spare, the spare's
    # stop, then the refill's count.
    spy = DockerDaemonSpy.new([[204, ''], [201, '{"Id":"e5ec1d"}'], [204, '']] +
                              refill_finds_a_full_node)
    runner = runner_using(spy)
    spares.add(image_name: image_name, container_id: 'warmed', expires_at: clock.now + 100)

    runner.run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal spy.endpoints_for(:claimed_a_spare, :execd_the_kata,
                                   :stopped_the_container, :spare_pool_is_full),
                 spy.endpoints
    assert_equal [:rename_container, 'warmed', container_name], spy.calls[0]
    exec_config = CyberDojoShContainerConfig.exec_config(id58)
    assert_equal [:create_exec, 'warmed', exec_config], spy.calls[1]
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf26', %w[
  | The pool holds a spare, and the test-run claims it.
  | The test-run warms another for that image_name, after the stop.
  | A claim then answers with the container that warm made.
  | The pool holds what it held before, one spare for that image_name.
  ] do
    spy = DockerDaemonSpy.new(
      [[204, ''], [201, '{"Id":"e5ec1d"}'], [204, '']] +
      [[200, '[]'], [201, '{"Id":"warmed"}'], [204, '']]
    )
    runner = runner_using(spy)
    spares.add(image_name: image_name, container_id: 'claimed', expires_at: clock.now + 100)

    runner.run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal spy.endpoints_for(:claimed_a_spare, :execd_the_kata,
                                   :stopped_the_container, :warmed_a_spare),
                 spy.endpoints
    assert_equal 'warmed', spares.claim(image_name: image_name, container_name: container_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf25', %w[
  | The pool holds no spare, so the run makes its own container.
  | The run warms a spare for that image_name.
  | The warm comes last, after the stop.
  | Nothing on the path to the answer waits for it.
  | A claim for that image_name then answers with the container the warm made.
  ] do
    spy = DockerDaemonSpy.new(
      responses_up_to_the_stream + [[204, '']] +
      [[200, '[]'], [201, '{"Id":"warmed"}'], [204, '']]
    )

    runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal spy.endpoints_for(:made_a_container, :execd_the_kata,
                                   :stopped_the_container, :warmed_a_spare),
                 spy.endpoints
    assert_equal 'warmed', spares.claim(image_name: image_name, container_name: container_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf24', %w(
  | The pool holds a spare.
  | The daemon refuses the exec in it with a 404.
  | The spare is discarded.
  | The run then makes its own container, as a run with no spare does.
  | It answers without timing out.
  | A spare can be dead by the time it is claimed.
  | A container made for the run cannot be.
  | The fallback is what keeps a pool from costing a learner a faulty light.
  | The exec create comes before the tgz is written.
  | So the kata never began in the spare.
  | The container made here runs the kata for the first time.
  | The dead spare is stopped too, as any container this run was given is.
  ) do
    gone = '{"message":"No such container: warmed"}'
    # In order: the claim's rename, the refused exec in the spare, the spare's
    # own stop, then a run making its own container.
    spy = DockerDaemonSpy.new(
      [[204, ''], [404, gone], [204, '']] + responses_up_to_the_stream +
      [[204, '']] + refill_finds_a_full_node
    )
    runner = runner_using(spy)
    spares.add(image_name: image_name, container_id: 'warmed', expires_at: clock.now + 100)

    result = runner.run(id58, image_name, container_name, max_seconds, tgz_in)

    refute result[:timed_out], 'timed_out'
    assert_equal spy.endpoints_for(:claimed_a_spare, :was_refused_an_exec,
                                   :stopped_the_container,
                                   :made_a_container, :execd_the_kata,
                                   :stopped_the_container, :spare_pool_is_full),
                 spy.endpoints
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf17', %w(
  | The run goes to the real daemon.
  | The kata is a fork bomb, and it saturates PidsLimit.
  | The container's send_tgz forks four processes: find, file, tar and gzip.
  | None of them can be forked under the bomb.
  | The container is removed.
  | The removal does not depend on how the bomb ends.
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

    assert removed?(http, name), "#{name} was not removed"
  ensure
    http.request('DELETE', "/containers/#{name}?force=true")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf18', %w(
  | The run goes to the real daemon.
  | The kata sleeps for longer than the run's max_seconds.
  | The run answers timed_out, with an empty stdout.
  | The container is removed.
  | A sleeping kata sends nothing, and nothing kills its PID 1.
  | So it cannot end early, as a fork bomb can.
  ) do
    http = DockerSocket.new
    set_context(http: http)
    name = "cyber_dojo_runner_#{id58}"

    result = cyber_dojo_sh_runner.run(id58, image_name, name, 1, real_tgz_in("sleep 30\n"))

    assert result[:timed_out], 'timed_out'
    assert_equal '', result[:stdout]
    assert removed?(http, name), "#{name} was not removed"
  ensure
    http.request('DELETE', "/containers/#{name}?force=true")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf19', %w(
  | The run goes to the real daemon.
  | The kata echoes hello, and the run does not time out.
  | The container's Cmd is a sleep, which outlives the exec that did the work.
  | The runner stops the container once it has the payload.
  | The container exits then, rather than at the end of its sleep.
  | AutoRemove removes a container that has exited.
  | So the container is removed.
  ) do
    http = DockerSocket.new
    set_context(http: http)
    name = "cyber_dojo_runner_#{id58}"

    result = cyber_dojo_sh_runner.run(id58, image_name, name, 10, real_tgz_in("echo hello\n"))

    refute result[:timed_out], 'timed_out'
    assert removed?(http, name), "#{name} was not removed"
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

  # AutoRemove removes the container once it has exited, which is not the
  # instant the stop returns.
  # A single answer at the end says whether it was removed, however many polls
  # it took, so giving up and finding it removed take the same path.
  # Inspecting a container by name is no part of what the runner does, so this
  # asks the transport rather than DockerDaemon.
  def removed?(http, name)
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

  # What the daemon answers the refill a run ends with. The node is already
  # full, so the refill stops at the count and creates nothing.
  # A test that is not about the pool wants it to end there.
  def refill_finds_a_full_node
    full = Array.new(SparePool::SPARES_PER_NODE) do |n|
      { 'Names' => [format('/cyber_dojo_spare_%<n>08x', n: n)] }
    end
    [[200, JSON.generate(full)]]
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
