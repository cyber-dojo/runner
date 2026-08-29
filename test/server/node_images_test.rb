require_relative '../test_base'
require_code 'externals/docker_socket'

class NodeImagesTest < TestBase

  test '9j5t9K', %w(
  | gcc_assert is believed to be on the node.
  | A pull for it answers :pulled.
  | No thread is started, and nothing is logged.
  | It is still believed to be there.
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new
    )
    assert_equal [], images.names
    images.add(gcc_assert)
    expected = :pulled
    actual = images.pull(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    assert_equal [gcc_assert], images.names
    refute context.threader.called
    assert_equal context.logger.logged, ''
  end

  # - - - - - - - - - - - - - - - - -

  test '9j5t9M', %w(
  | gcc_assert is not believed to be on the node.
  | A pull for it answers :pulling.
  | The pull runs on a thread, and asks the daemon for that image_name.
  | The image is then believed to be there.
  | The log says which image was pulled, and how long it took.
  | The clock is the context's, so the test says what that duration is.
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      clock: ClockStub.new(from: 1000.0, advancing_by: 2.5),
      docker: DockerDaemonSpy.new([[200, pull_progress]])
    )
    assert_equal [], images.names
    expected = :pulling
    actual = images.pull(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    assert context.threader.called
    assert_equal [gcc_assert], images.names
    assert_equal "Pulled docker image #{gcc_assert} (2.5 secs)\n", context.logger.logged
    assert_equal [[:pull_image, gcc_assert]], docker.calls
  end

  # - - - - - - - - - - - - - - - - -

  test '9j5t9N', %w(
  | gcc_assert is not believed to be on the node.
  | The daemon refuses the pull with a 404.
  | The pull answers :pulling, and runs on a thread.
  | The answer says a pull was started, not that it finished.
  | The image is still not believed to be there.
  | The log names the image and the kata that asked.
  | It names the status code too, and what the daemon said.
  ) do
    # The daemon resolves the reference before it answers, so a name no
    # registry can serve arrives as a 404 rather than as an error part way
    # through a stream that has already begun.
    body = %({"message":"pull access denied for #{gcc_assert}, repository does not exist"})
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      docker: DockerDaemonSpy.new([[404, body]])
    )
    assert_equal [], images.names
    expected = :pulling
    actual = images.pull(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    assert context.threader.called
    assert_equal [], images.names

    log_message = "Failed to pull docker image #{gcc_assert}, id=#{id}, code=404, body=#{body}\n"
    assert_equal context.logger.logged, log_message
  end

  # - - - - - - - - - - - - - - - - -

  test '9j5t9R', %w(
  | The daemon answers the pull 200, and the transfer then fails.
  | The status code goes out before the transfer starts.
  | A failure part way through cannot change it.
  | The stream carries an error object instead.
  | The pull answers :pulling.
  | The image is not believed to be on the node.
  | The log names the image, the kata, the status code, and the stream.
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
      docker: DockerDaemonSpy.new([[200, body]])
    )

    assert_equal :pulling, images.pull(id: id, image_name: gcc_assert)

    assert_equal [], images.names
    log_message = "Failed to pull docker image #{gcc_assert}, id=#{id}, code=200, body=#{body}\n"
    assert_equal context.logger.logged, log_message
  end

  # - - - - - - - - - - - - - - - - -

  test '9j5t9P', %w(
  | gcc_assert is not believed to be on the node.
  | A pull for it is already under way.
  | A second pull for it answers :pulling, and starts no thread.
  | Nothing is logged.
  | The image is still not believed to be there.
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new
    )

    images.instance_variable_get(:@pulling).add(gcc_assert)
    assert_equal [], images.names
    expected = :pulling
    actual = images.pull(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    refute context.threader.called
    assert_equal [], images.names
    assert_equal context.logger.logged, ''
  end

  test '9j5t9S', %w(
  | The pull goes to the real daemon.
  | It answers :pulling.
  | alpine:3.24 is then believed to be on the node.
  | The log says it was pulled.
  | The duration in it comes from the real clock, so the test does not pin it.
  | A stub cannot judge the query the runner builds, or an error-free stream.
  | Only the daemon can.
  ) do
    # alpine:3.24 is on the node before the tests start, put there by
    # bin/setup_dependent_images.sh, so this re-pull downloads nothing and
    # answers Status: Image is up to date.
    alpine = 'alpine:3.24'
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      http: DockerSocket.new
    )

    assert_equal :pulling, images.pull(id: id, image_name: alpine)

    assert_equal [alpine], images.names
    assert_includes context.logger.logged, "Pulled docker image #{alpine} ("
  end

  # - - - - - - - - - - - - - - - - -

  test '3q1Ps3', %w[
  | The daemon answers with the images the node holds.
  | Seeding believes every RepoTags entry the daemon gives.
  | One image can carry several tags, and all of them are believed.
  | A tag whose registry names a port keeps that port.
  | The names come back in name order, not the order the daemon gave.
  | The daemon is asked once.
  ] do
    set_context(docker: DockerDaemonSpy.new([[200, JSON.generate(daemon_images)]]))

    images.seed

    assert_equal expected_names, images.names
    assert_equal [[:image_names]], docker.calls
  end

  # - - - - - - - - - - - - - - - - -

  test '3q1Ps4', %w[
  | The daemon's answer holds two images with no RepoTags at all.
  | Seeding adds nothing for them.
  | A dangling image carries no name a kata could ask for.
  | The rest are believed exactly as they are.
  | The daemon's images are shuffled, so the order they arrive in varies.
  | The names still come back in name order.
  ] do
    dangling = [
      { 'Id' => 'sha256:34a35c5c04b4a0e5cfdd853a8477192634f5a1a5a54b6a80b3b33edd1e7fcdcb',
        'RepoTags' => [] },
      { 'Id' => 'sha256:34692745a2bfde5d67ba19550b5a3aed1110ec5aabb4cdc2cf72541d5e516e33',
        'RepoTags' => [] }
    ]
    tainted = (daemon_images + dangling).shuffle
    set_context(docker: DockerDaemonSpy.new([[200, JSON.generate(tainted)]]))

    images.seed

    assert_equal expected_names, images.names
  end

  # - - - - - - - - - - - - - - - - -

  test '3q1Ps6', %w[
  | The daemon answers the seed 400.
  | Seeding raises, and the error carries what the daemon said.
  | config.ru seeds once at boot.
  | A worker that knows of no images answers :pulling to every test-run.
  | So a worker that cannot learn what the node holds does not start.
  ] do
    message = '{"message":"client version 1.22 is too old"}'
    set_context(docker: DockerDaemonSpy.new([[400, message]]))

    error = assert_raises { images.seed }

    assert_equal message, error.message
  end

  # - - - - - - - - - - - - - - - - -

  test '3q1Ps8', %w[
  | The seed goes to the real daemon.
  | A tag this test owns is not among the names it answers.
  | The daemon then tags alpine:3.24 with that name.
  | A second seed answers the names again, and the new tag is among them.
  | A stub cannot judge the socket request, its headers, or its chunked body.
  | Only the daemon can.
  ] do
    set_context(http: client = DockerSocket.new)
    tagged = "#{owned_repo}:v1"

    images.seed
    refute_includes images.names, tagged

    code, body = client.request('POST', "/images/alpine:3.24/tag?repo=#{owned_repo}&tag=v1")
    assert_equal 201, code, body

    images.seed
    assert_includes images.names, tagged
  ensure
    # The tag is this test's own, so removing it takes nothing else with it.
    # alpine:3.24 keeps the image alive for the tests that pulled it.
    client.request('DELETE', "/images/#{tagged}")
  end

  private

  # Lowercase because a repository name may not carry capitals, and per-test
  # so that a name this test asserts the absence of cannot be one another
  # test, or another run, put there.
  def owned_repo
    "cyber-dojo-node-images-test-#{id58.downcase}"
  end

  # As GET /images/json answers them, out of alphabetical order, and with
  # fields alongside RepoTags that say nothing about what an image is named.
  def daemon_images
    [
      { 'Id' => 'sha256:8fabf019a49303ba48925e4769944d3d27f02fee2b581c09537fa82f9f758951',
        'RepoTags' => ['cyberdojo/runner:83c2554', 'cyberdojo/runner:latest'] },
      { 'Id' => 'sha256:0ce768d6bf6ca3e2bd001cb7a014df7cfb92bed461e7da6bb5bb9637fd92ffc5',
        'RepoTags' => ['openjdk:13-jdk-alpine'] },
      { 'Id' => 'sha256:30e6b0d669915981e3fa85a7debbc2d81bf23a2289f3d772ac8d642e2fc5b3aa',
        'RepoTags' => ['cyberdojo/saver:723349e'] },
      { 'Id' => 'sha256:1fce37b0a7ba4b9e5c0d8e1f2a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d',
        'RepoTags' => ['registry.example.com:5000/gcc_assert:2f1a3c9'] }
    ]
  end

  def expected_names
    %w[
      cyberdojo/runner:83c2554
      cyberdojo/runner:latest
      cyberdojo/saver:723349e
      openjdk:13-jdk-alpine
      registry.example.com:5000/gcc_assert:2f1a3c9
    ].sort
  end

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
