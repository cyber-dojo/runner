require_relative '../test_base'
require_code 'cyber_dojo_sh_container_config'
require_code 'cyber_dojo_sh_runner'
require_code 'home_files'
require_code 'externals/docker_socket'

class CyberDojoShRunnerTest < TestBase

  test 'c9Gf10', %w(
  | A run creates a container, attaches to it, and then starts it.
  | The container is named for the run.
  | Its config carries everything the run needs.
  | That is the image, the command that runs the kata, and this run's id.
  | Attaching before starting is what stops the container's first bytes
  | reaching nobody.
  ) do
    spy = DockerDaemonSpy.new(create_and_start_responses)

    runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal spy.endpoints_for(:ran_the_kata), spy.endpoints
    endpoint, config, name = spy.calls[0]
    assert_equal :create_container, endpoint
    assert_equal CyberDojoShContainerConfig.create_config(id58, image_name), config
    assert_equal container_name, name
    assert_equal [:attach_container, 'c0ffee'], spy.calls[1]
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf12', %w(
  | The tgz is written to the stream.
  | The writing half is then closed.
  | That close is what gives the container's [tar -zxf -] its end of file.
  ) do
    spy = DockerDaemonSpy.new(create_and_start_responses)

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
      create_and_start_responses,
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
  | The container is stopped, which a run that finishes never has to do.
  | Its cyber-dojo.sh is still going, so nothing else would end it.
  | The stop sends SIGTERM at once, and SIGKILL one second later.
  | That second is what gives cyber-dojo.sh's EXIT trap its chance to run.
  ) do
    spy = DockerDaemonSpy.new(
      create_and_start_responses + [[204, '']],
      stalls: true
    )

    result = runner_using(spy).run(id58, image_name, container_name, 0.1, tgz_in)

    assert result[:timed_out], 'timed_out'
    # Empty rather than absent: there is no payload, and the result keeps the
    # same shape whether the run finished or not.
    assert_equal '', result[:stdout]
    assert_equal '', result[:stderr]
    assert_equal spy.endpoints_for(:ran_the_kata, :stopped_the_container),
                 spy.endpoints
    assert_equal [:stop_container, 'c0ffee', 1], spy.calls.last
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

    error = assert_raises(CyberDojoShRunner::RunRefused) do
      runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)
    end

    assert_includes error.message, '409'
    assert_includes error.message, 'already in use'
    assert_equal %i[create_container], spy.endpoints
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf20', %w(
  | The container is created, and the daemon refuses to start it with a 409.
  | The run raises rather than reading a stream nothing will ever write to.
  | The error names the status code, and what the daemon said.
  ) do
    conflict = '{"message":"Conflict. The container has been removed"}'
    spy = DockerDaemonSpy.new([[201, '{"Id":"c0ffee"}'], [409, conflict]])

    error = assert_raises(CyberDojoShRunner::RunRefused) do
      runner_using(spy).run(id58, image_name, container_name, max_seconds, tgz_in)
    end

    assert_includes error.message, '409'
    assert_includes error.message, 'has been removed'
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
  | The container's Cmd is the kata, so it exits when the kata is done.
  | AutoRemove removes a container that has exited.
  | So the container is removed with nothing else asked of the daemon.
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
  def runner_using(daemon)
    set_context(docker: daemon)
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

  # What the daemon answers the two calls a run makes that expect a reply: the
  # container created, and the container started. The attach between them
  # answers a stream rather than a status, so it needs no canned response.
  def create_and_start_responses
    [[201, '{"Id":"c0ffee"}'], [204, '']]
  end

  def container_name
    'cyber_dojo_runner_stub'
  end

  def tgz_in
    'would-be-a-tgz'
  end
end
