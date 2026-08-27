require_relative '../test_base'
require_code 'cyber_dojo_sh_container_config'
require_code 'cyber_dojo_sh_runner'
require_code 'home_files'
require_code 'externals/docker_socket'

class CyberDojoShRunnerTest < TestBase

  test 'c9Gf10', %w(
  | the run creates a container of its own name
  | saying in json what the docker CLI is told in flags
  ) do
    spy = DockerDaemonSpy.new([[201, '{"Id":"c0ffee"}']])

    CyberDojoShRunner.new(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    endpoint, config, name = spy.calls[0]
    assert_equal :create_container, endpoint
    assert_equal CyberDojoShContainerConfig.create_config(id58, image_name), config
    assert_equal container_name, name
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf11', %w(
  | the stream is attached before the container is started
  | so that nothing it writes is missed
  | and both name the id the create answered
  ) do
    spy = DockerDaemonSpy.new([[201, '{"Id":"c0ffee"}'], [204, '']])

    CyberDojoShRunner.new(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal [:attach_container, 'c0ffee'], spy.calls[1]
    assert_equal [:start_container, 'c0ffee'], spy.calls[2]
    assert_equal %i[create_container attach_container start_container], spy.endpoints
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf12', %w(
  | the tgz is written to the stream, and the writing half is then closed
  | which is what gives the container's [tar -zxf -] its end of file
  | and without which it waits for one that never comes
  ) do
    spy = DockerDaemonSpy.new([[201, '{"Id":"c0ffee"}'], [204, '']])

    CyberDojoShRunner.new(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal tgz_in, spy.written
    assert spy.write_half_closed, 'write_half_closed'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf13', %w(
  | the container's two streams are answered separately
  | the payload arriving on stdout, and anything it complained about on stderr
  ) do
    spy = DockerDaemonSpy.new(
      [[201, '{"Id":"c0ffee"}'], [204, '']],
      frames: [[1, 'the-payload'], [2, 'a warning']]
    )

    result = CyberDojoShRunner.new(spy).run(id58, image_name, container_name, max_seconds, tgz_in)

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
      [[201, '{"Id":"c0ffee"}'], [204, ''], [204, '']],
      stalls: true
    )

    result = CyberDojoShRunner.new(spy).run(id58, image_name, container_name, 0.1, tgz_in)

    assert result[:timed_out], 'timed_out'
    # Empty rather than absent: there is no payload, and the result keeps the
    # same shape whether the run finished or not.
    assert_equal '', result[:stdout]
    assert_equal '', result[:stderr]
    assert_equal [:stop_container, 'c0ffee', 1], spy.calls.last
    assert_equal %i[create_container attach_container start_container stop_container], spy.endpoints
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

    result = CyberDojoShRunner.new(docker).run(id58, image_name, name, 10, real_tgz_in("echo hello\n"))

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
  ) do
    conflict = '{"message":"Conflict. The container name is already in use"}'
    spy = DockerDaemonSpy.new([[409, conflict]])

    error = assert_raises(CyberDojoShRunner::DaemonRefused) do
      CyberDojoShRunner.new(spy).run(id58, image_name, container_name, max_seconds, tgz_in)
    end

    assert_includes error.message, '409'
    assert_includes error.message, 'already in use'
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
    CyberDojoShRunner.new(docker).run(id58, image_name, name, 2, real_tgz_in(FORK_BOMB))

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

    result = CyberDojoShRunner.new(docker).run(id58, image_name, name, 1, real_tgz_in("sleep 30\n"))

    assert result[:timed_out], 'timed_out'
    assert_equal '', result[:stdout]
    assert gone?(http, name), "#{name} was left behind"
  ensure
    http.request('DELETE', "/containers/#{name}?force=true")
  end

  private

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

  def container_name
    'cyber_dojo_runner_stub'
  end

  def tgz_in
    'would-be-a-tgz'
  end
end
