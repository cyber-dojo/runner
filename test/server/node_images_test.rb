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

  test '9j5t9T', %w(
  | gcc_assert is not believed to be on the node, but the daemon holds it.
  | Another worker pulled it, or it arrived after this worker seeded.
  | The pull answers :pulled rather than telling a learner to wait.
  | It is believed to be there from then on, so the daemon is asked once.
  | No pull is started, and nothing is logged.
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      docker: DockerDaemonSpy.new([[200, image_inspect]])
    )
    assert_equal [], images.names

    assert_equal :pulled, images.pull(id: id, image_name: gcc_assert)
    assert_equal :pulled, images.pull(id: id, image_name: gcc_assert)

    assert_equal [gcc_assert], images.names
    assert_equal [[:image_exists, gcc_assert]], docker.calls
    refute context.threader.called
    assert_equal '', context.logger.logged
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
      docker: DockerDaemonSpy.new([[404, image_not_found], [200, pull_progress]])
    )
    assert_equal [], images.names
    expected = :pulling
    actual = images.pull(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    assert context.threader.called
    assert_equal [gcc_assert], images.names
    assert_equal "Pulled docker image #{gcc_assert} (2.5 secs)\n", context.logger.logged
    assert_equal [[:image_exists, gcc_assert], [:pull_image, gcc_assert]], docker.calls
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
      docker: DockerDaemonSpy.new([[404, image_not_found], [404, body]])
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
      docker: DockerDaemonSpy.new([[404, image_not_found], [200, body]])
    )

    assert_equal :pulling, images.pull(id: id, image_name: gcc_assert)

    assert_equal [], images.names
    log_message = "Failed to pull docker image #{gcc_assert}, id=#{id}, code=200, body=#{body}\n"
    assert_equal context.logger.logged, log_message
  end

  # - - - - - - - - - - - - - - - - -

  test '9j5t9P', %w(
  | gcc_assert is not believed to be on the node.
  | A pull for it answers :pulling, and starts the pull on a thread.
  | A second pull for it answers :pulling too.
  | It starts no second thread, so the image is pulled once however many
  | test-runs ask for it while it is on its way.
  | Neither pull has finished, so nothing is logged and the image is not
  | believed to be there.
  ) do
    # The daemon is asked on each of the two misses, and says no each time:
    # the pull is deferred, so nothing has reached the node in between.
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderDeferred.new,
      docker: DockerDaemonSpy.new([[404, image_not_found], [404, image_not_found]])
    )

    assert_equal :pulling, images.pull(id: id, image_name: gcc_assert)
    assert_equal :pulling, images.pull(id: id, image_name: gcc_assert)

    assert_equal 1, context.threader.deferred
    assert_equal [], images.names
    assert_equal '', context.logger.logged
  end

  # A pull answers :pulled for anything the node already holds, so a pull
  # through here can no longer reach the daemon's pull endpoint without
  # downloading an image the node lacks. test/client/pull_image_test.rb
  # already pulls an absent image through the whole runner, so that is where
  # a real pull is, and nothing here downloads anything.

  test '9j5t9U', %w(
  | alpine:3.24 is on the node, and this worker does not believe it is.
  | The real daemon is asked, and says the node holds it.
  | The pull answers :pulled, and nothing is pulled.
  | This is the case a worker that did not perform the pull is in.
  | A stub cannot judge the inspect query the runner builds. Only the daemon can.
  ) do
    # alpine:3.24 is on the node before the tests start, put there by
    # bin/setup_dependent_images.sh.
    alpine = 'alpine:3.24'
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      http: DockerSocket.new
    )

    assert_equal :pulled, images.pull(id: id, image_name: alpine)

    assert_equal [alpine], images.names
    refute context.threader.called
    assert_equal '', context.logger.logged
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

  # As GET /images/{name}/json answers for an image the node holds. Only the
  # status code decides anything, so the body carries just enough to look
  # like an inspect rather than all of one.
  def image_inspect
    JSON.generate({
      'Id' => 'sha256:93eefc6d1c2b7a4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6',
      'RepoTags' => [gcc_assert]
    })
  end

  # As GET /images/{name}/json answers for an image the node does not hold.
  def image_not_found
    %({"message":"No such image: #{gcc_assert}"})
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
