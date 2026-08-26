require_relative '../test_base'
require_code 'cyber_dojo_sh_container_config'
require_code 'daemon_run'
require_code 'home_files'
require_code 'externals/unix_socket_http'

class DaemonRunTest < TestBase

  test 'c9Gf10', %w(
  | the run creates a container of its own name
  | saying in json what the docker CLI is told in flags
  ) do
    client = UnixSocketHttpStub.new([[201, '{"Id":"c0ffee"}']])

    DaemonRun.new(client).run(id58, image_name, container_name, max_seconds, tgz_in)

    method, path, body = client.calls[0]
    assert_equal 'POST', method
    assert_equal "/containers/create?name=#{container_name}", path
    assert_equal CyberDojoShContainerConfig.create_config(id58, image_name), body
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf11', %w(
  | the stream is attached before the container is started
  | so that nothing it writes is missed
  | and both name the id the create answered
  ) do
    client = UnixSocketHttpStub.new([[201, '{"Id":"c0ffee"}'], [204, '']])

    DaemonRun.new(client).run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal '/containers/c0ffee/attach?stream=1&stdin=1&stdout=1&stderr=1', client.attached
    assert_equal ['POST', '/containers/c0ffee/start', nil], client.calls[1]
    assert_equal %w[create attach start], client.order
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf12', %w(
  | the tgz is written to the stream, and the writing half is then closed
  | which is what gives the container's [tar -zxf -] its end of file
  | and without which it waits for one that never comes
  ) do
    client = UnixSocketHttpStub.new([[201, '{"Id":"c0ffee"}'], [204, '']])

    DaemonRun.new(client).run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal tgz_in, client.written
    assert client.write_half_closed, 'write_half_closed'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf13', %w(
  | the container's two streams are answered separately
  | the payload arriving on stdout, and anything it complained about on stderr
  ) do
    client = UnixSocketHttpStub.new(
      [[201, '{"Id":"c0ffee"}'], [204, '']],
      frames: [[1, 'the-payload'], [2, 'a warning']]
    )

    result = DaemonRun.new(client).run(id58, image_name, container_name, max_seconds, tgz_in)

    assert_equal 'the-payload', result[:stdout]
    assert_equal 'a warning', result[:stderr]
    refute result[:timed_out], 'timed_out'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf14', %w(
  | a container still sending nothing when max_seconds passes is stopped
  | and the run answers timed_out, with no partial payload
  | --time 1 being SIGTERM and then SIGKILL a second later
  | so cyber-dojo.sh's own EXIT trap still gets its chance
  ) do
    client = UnixSocketHttpStub.new(
      [[201, '{"Id":"c0ffee"}'], [204, ''], [204, '']],
      stalls: true
    )

    result = DaemonRun.new(client).run(id58, image_name, container_name, 0.1, tgz_in)

    assert result[:timed_out], 'timed_out'
    # Empty rather than absent: there is no payload, and the result keeps the
    # same shape whether the run finished or not.
    assert_equal '', result[:stdout]
    assert_equal '', result[:stderr]
    assert_equal ['POST', '/containers/c0ffee/stop?t=1', nil], client.calls.last
    assert_equal %w[create attach start stop], client.order
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf15', %w(
  | a real run against the real daemon
  | which is the only thing that says the daemon accepts the config,
  | the attach path, and the headers, none of which a stub can judge
  ) do
    client = UnixSocketHttp.new('/var/run/docker.sock')
    name = "cyber_dojo_runner_#{id58}"

    result = DaemonRun.new(client).run(id58, image_name, name, 10, real_tgz_in("echo hello\n"))

    refute result[:timed_out], 'timed_out'
    files = TGZ.files(result[:stdout])
    assert_equal '0', files['tmp/status']
    assert_equal "hello\n", files['tmp/stdout']
  ensure
    # AutoRemove disposes of a container that exits, but not of one that never
    # started, and this name is the same on every run. Without this a failure
    # here leaves a container that makes the next run collide with it.
    client.request('DELETE', "/containers/#{name}?force=true")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf16', %w(
  | a create the daemon refuses raises, naming what it said
  | rather than carrying on with no container id
  | eg a name already taken by a container that never started
  ) do
    conflict = '{"message":"Conflict. The container name is already in use"}'
    client = UnixSocketHttpStub.new([[409, conflict]])

    error = assert_raises(DaemonRun::DaemonRefused) do
      DaemonRun.new(client).run(id58, image_name, container_name, max_seconds, tgz_in)
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
    client = UnixSocketHttp.new('/var/run/docker.sock')
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
    DaemonRun.new(client).run(id58, image_name, name, 2, real_tgz_in(FORK_BOMB))

    assert gone?(client, name), "#{name} was left behind"
  ensure
    client.request('DELETE', "/containers/#{name}?force=true")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'c9Gf18', %w(
  | a real container that sends nothing before the deadline times out
  | and is stopped, with no partial payload to report
  | a sleeping kata rather than a bomb, because a sleep cannot end early:
  | it sends nothing and nothing kills its PID 1
  ) do
    client = UnixSocketHttp.new('/var/run/docker.sock')
    name = "cyber_dojo_runner_#{id58}"

    result = DaemonRun.new(client).run(id58, image_name, name, 1, real_tgz_in("sleep 30\n"))

    assert result[:timed_out], 'timed_out'
    assert_equal '', result[:stdout]
    assert gone?(client, name), "#{name} was left behind"
  ensure
    client.request('DELETE', "/containers/#{name}?force=true")
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
  def gone?(client, name)
    code = nil
    20.times do
      code, _body = client.request('GET', "/containers/#{name}/json")
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

  # Answers each canned response in turn, and records what it was asked, and
  # in what order. The attach answers an empty stream, which reads as a
  # container that sent nothing.
  class UnixSocketHttpStub
    attr_reader :calls, :attached, :order

    def initialize(responses, frames: [], stalls: false)
      @responses = responses
      @frames = frames
      @stalls = stalls
      @calls = []
      @order = []
    end

    def request(method, path, body = nil)
      @calls << [method, path, body]
      @order << step_of(path)
      @responses.shift
    end

    def attach(path)
      @attached = path
      @order << 'attach'
      @stream = AttachStreamSpy.new(@frames, @stalls)
    end

    def written
      @stream.written
    end

    def write_half_closed
      @stream.write_half_closed
    end

    private

    def step_of(path)
      %w[create start stop].find { |step| path.include?(step) }
    end
  end

  # Stands in for the hijacked socket. It reads back the given frames as the
  # daemon would frame them, and remembers what was written to it and whether
  # the writing half was shut down.
  class AttachStreamSpy
    attr_reader :written, :write_half_closed

    def initialize(frames, stalls = false)
      @bytes = frames.map { |stream, payload| framed(stream, payload) }.join
      @stalls = stalls
      @at = 0
      @written = +''
      @write_half_closed = false
    end

    # DeadlineReader sets the budget left on the stream before every read,
    # which a real socket honours. Nothing here blocks, so it is ignored.
    attr_writer :timeout

    def write(bytes)
      @written << bytes
    end

    def close_write
      @write_half_closed = true
    end

    # A stalling container is alive and sending nothing, which a real socket
    # answers by blocking until its timeout expires.
    def read(size)
      raise IO::TimeoutError if @stalls
      return nil if @at >= @bytes.bytesize

      chunk = @bytes.byteslice(@at, size)
      @at += chunk.bytesize
      chunk
    end

    private

    def framed(stream, payload)
      [stream, payload.bytesize].pack('C x3 N') + payload
    end
  end
end
