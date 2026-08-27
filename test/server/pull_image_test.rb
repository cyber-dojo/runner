require_relative '../test_base'
require_code 'externals/unix_socket_http'

class PullImageTest < TestBase

  test '9j5t9K', %w(
  | given gcc_assert HAS already been pulled,
  | when I call pull_image(id,gcc_assert),
  | then a new thread is not started
  | no shell command is run,
  | nothing is logged,
  | and the result is :pulled
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new
    )
    assert_equal [], puller.image_names
    puller.add(gcc_assert)
    expected = :pulled
    actual = puller.pull_image(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    assert_equal [gcc_assert], puller.image_names
    refute context.threader.called
    assert_equal context.logger.logged, ''
  end

  # - - - - - - - - - - - - - - - - -

  test '9j5t9M', %w(
  | given gcc_assert has NOT already been pulled,
  | when I call pull_image(id, gcc_assert),
  | then the pull runs in a new thread against the daemon
  | and a message is logged
  | and the result is :pulling
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      daemon: daemon = DaemonOneRequestStub.new([200, pull_progress])
    )
    assert_equal [], puller.image_names
    expected = :pulling
    actual = puller.pull_image(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    assert context.threader.called
    assert_equal [gcc_assert], puller.image_names
    assert_equal context.logger.logged, "Pulled docker image #{gcc_assert} (0.0 secs)\n"
    assert_equal ['POST', "/images/create?fromImage=#{gcc_assert}", nil], daemon.call
  end

  # - - - - - - - - - - - - - - - - -

  test '9j5t9N', %w(
  | given gcc_assert has NOT already been pulled,
  | when I call pull_image(id, gcc_assert),
  | then the pull runs in a new thread
  | and if the daemon refuses the pull a message is logged
  | naming the code and what it said
  | and gcc_assert is not pulled
  | and the result is :pulling
  ) do
    # The daemon resolves the reference before it answers, so a name no
    # registry can serve arrives as a 404 rather than as an error part way
    # through a stream that has already begun.
    body = %({"message":"pull access denied for #{gcc_assert}, repository does not exist"})
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      daemon: DaemonOneRequestStub.new([404, body])
    )
    assert_equal [], puller.image_names
    expected = :pulling
    actual = puller.pull_image(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    assert context.threader.called
    assert_equal [], puller.image_names

    log_message = "Failed to pull docker image #{gcc_assert}, code=404, body=#{body}\n"
    assert_equal context.logger.logged, log_message
  end

  # - - - - - - - - - - - - - - - - -

  test '9j5t9R', %w(
  | a pull the daemon starts and cannot finish answers 200,
  | having already committed to a status code before the transfer failed,
  | and says so with an error object in the stream
  | so gcc_assert is not pulled and the failure is logged
  ) do
    # UNVERIFIED against a real daemon. A 404 for an unresolvable name was
    # probed; forcing a transfer to fail after the 200 needs a registry that
    # misbehaves on purpose, so the stream below is docker's documented shape
    # rather than one this repo has seen.
    body = [
      %({"status":"Pulling from cyberdojofoundation/gcc_assert","id":"93eefc6"}),
      %({"errorDetail":{"message":"unexpected EOF"},"error":"unexpected EOF"})
    ].join("\n")
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      daemon: DaemonOneRequestStub.new([200, body])
    )

    assert_equal :pulling, puller.pull_image(id: id, image_name: gcc_assert)

    assert_equal [], puller.image_names
    log_message = "Failed to pull docker image #{gcc_assert}, code=200, body=#{body}\n"
    assert_equal context.logger.logged, log_message
  end

  # - - - - - - - - - - - - - - - - -

  test '9j5t9P', %w(
  | given gcc_assert has NOT already been pulled,
  | but is currently being pulled,
  | when I call pull_image(id, gcc_assert),
  | then the docker-pull does NOT run
  | nothing is logged
  | and the result is :pulling
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new
    )

    puller.instance_variable_get(:@pulling).add(gcc_assert)
    assert_equal [], puller.image_names
    expected = :pulling
    actual = puller.pull_image(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    refute context.threader.called
    assert_equal [], puller.image_names
    assert_equal context.logger.logged, ''
  end

  test '9j5t9S', %w(
  | a real pull against the real daemon,
  | which is the only thing that says the query the runner builds names an
  | image the daemon will accept, and that a stream it answers 200 to
  | carries no error, neither of which a stub can judge
  ) do
    # alpine:3.24 is on the node before the tests start, put there by
    # bin/setup_dependent_images.sh, so this re-pull downloads nothing and
    # answers Status: Image is up to date.
    alpine = 'alpine:3.24'
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      daemon: UnixSocketHttp.new('/var/run/docker.sock')
    )

    assert_equal :pulling, puller.pull_image(id: id, image_name: alpine)

    assert_equal [alpine], puller.image_names
    assert_includes context.logger.logged, "Pulled docker image #{alpine} ("
  end

  private

  def gcc_assert
    'cyberdojofoundation/gcc_assert:93eefc6'
  end

  # Newline-delimited JSON, as POST /images/create streams it, ending in the
  # Status: line docker writes when the pull completes.
  def pull_progress
    [
      %({"status":"Pulling from cyberdojofoundation/gcc_assert","id":"93eefc6"}),
      %({"status":"Download complete","progressDetail":{"hidecounts":true},"id":"df8ce8557afe"}),
      %({"status":"Status: Downloaded newer image for #{gcc_assert}"})
    ].join("\n")
  end
end
