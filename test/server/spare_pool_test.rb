require_relative '../test_base'
require_code 'cyber_dojo_sh_container_config'

class SparePoolTest < TestBase

  test '7Bq2E1', %w(
  | a pool holding no spare for an image answers nothing,
  | which is a miss, and a miss is a test-run creating its own container
  | exactly as one does with no pool behind it at all
  ) do
    set_context

    assert_nil spares.claim(image_name: an_image)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E2', %w(
  | a spare is handed out once and is then gone from the pool,
  | nothing being recycled: one test-run, one container, so that what one
  | kata left behind is never something the next one inherits
  ) do
    set_context
    spare = add_spare(image_name: an_image, seconds_left: outlives_a_run)

    assert_equal spare, spares.claim(image_name: an_image)
    assert_nil spares.claim(image_name: an_image)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E3', %w(
  | spares are held per image, so a claim is never given one made for a
  | different image,
  | which is what lets two katas on one language share a pool while two on
  | different languages share nothing
  ) do
    set_context
    spare = add_spare(image_name: a_different_image, seconds_left: outlives_a_run)

    assert_nil spares.claim(image_name: an_image)
    assert_equal spare, spares.claim(image_name: a_different_image)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E4', %w(
  | a spare with too little of its sleep left is not handed to a test-run
  | an exec does not outlive its container's PID 1, so a sleep ending under
  | a run kills the kata part way, and the runner then reads a truncated
  | payload and answers the learner faulty for a kata that was fine
  | see docs/profiling/check_spare_sleep_ending_under_a_run.sh
  ) do
    set_context
    add_spare(image_name: an_image, seconds_left: dies_under_a_run)

    assert_nil spares.claim(image_name: an_image)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E5', %w(
  | a spare too near its expiry is dropped rather than left to be considered
  | again, and the one behind it is handed out in its place,
  | so one dying spare costs a claim nothing but the looking
  ) do
    set_context
    add_spare(image_name: an_image, seconds_left: dies_under_a_run)
    survivor = add_spare(image_name: an_image, seconds_left: outlives_a_run)

    assert_equal survivor, spares.claim(image_name: an_image)
    assert_nil spares.claim(image_name: an_image)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E6', %w(
  | warming an image creates a container from that image alone and starts it,
  | on a thread, so that whatever asked for a spare waits for neither
  | and names it with a prefix every worker's spares share, which is what
  | lets the cap count them all without knowing how many workers there are
  ) do
    threader = ThreaderSynchronous.new
    daemon = daemon_holding(an_empty_node, creating: '7c1e04d9')
    set_context(docker: daemon, threader: threader, random: RandomHex8Stub.new('9a3b1c7d'))

    spares.warm(image_name: an_image)

    assert threader.called, 'threader'
    assert_equal %i[containers_named create_container start_container], daemon.endpoints
    _endpoint, config, name = daemon.calls[1]
    assert_equal CyberDojoShContainerConfig.image_config(an_image), config
    assert_equal 'cyber_dojo_spare_9a3b1c7d', name
    assert_equal [:start_container, '7c1e04d9'], daemon.calls[2]
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E7', %w(
  | a warmed spare is in the pool to be claimed, and lives long enough to be,
  | its life being the sleep its container was created with
  ) do
    daemon = daemon_holding(an_empty_node, creating: 'b52f8a30')
    set_context(docker: daemon, threader: ThreaderSynchronous.new)

    spares.warm(image_name: an_image)

    assert_equal 'b52f8a30', spares.claim(image_name: an_image)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E8', %w(
  | a node already holding as many spares as it is allowed gets no more,
  | the count coming from the daemon rather than from this worker's memory,
  | because the cap is the node's and a worker cannot see its peers
  | and the name is what is counted, since a claimed container keeps the
  | label it was created with and would otherwise be counted as a spare
  ) do
    daemon = daemon_holding(a_full_node)
    set_context(docker: daemon, threader: ThreaderSynchronous.new)

    spares.warm(image_name: an_image)

    assert_equal [[:containers_named, 'cyber_dojo_spare_']], daemon.calls
    assert_nil spares.claim(image_name: an_image)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E9', %w(
  | a create the daemon refuses stops the warm there, nothing being started
  | and nothing put in the pool,
  | rather than an entry no container answers to, which costs a slot and
  | answers every claim of it as though the pool were empty,
  | and says so in the log, there being nobody waiting on a warm to tell
  ) do
    refused = %({"message":"No such image: #{an_image}"})
    daemon = daemon_refusing_create(404, refused)
    set_context(docker: daemon, threader: ThreaderSynchronous.new,
                logger: StdoutLoggerSpy.new)

    spares.warm(image_name: an_image)

    assert_equal %i[containers_named create_container], daemon.endpoints
    expected = "Failed to warm docker image #{an_image}, code=404, body=#{refused}\n"
    assert_equal expected, context.logger.logged
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E10', %w(
  | a create refused 404 says the image has left the node, so the image is
  | forgotten and the next test-run for it pulls rather than being told it is
  | already there,
  | which is the same 404 the run path acts on, noticed earlier: at warm time
  | no learner has been shown anything yet
  ) do
    refused = %({"message":"No such image: #{an_image}"})
    set_context(docker: daemon_refusing_create(404, refused),
                threader: ThreaderSynchronous.new, logger: StdoutLoggerSpy.new)
    images.add(an_image)
    assert_equal [an_image], images.names

    spares.warm(image_name: an_image)

    assert_equal [], images.names
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E11', %w(
  | a create refused for any other reason leaves the image alone,
  | eg a spare name already taken by a container that never started, which
  | says nothing about whether the image is on the node
  ) do
    conflict = '{"message":"Conflict. The container name is already in use"}'
    set_context(docker: daemon_refusing_create(409, conflict),
                threader: ThreaderSynchronous.new, logger: StdoutLoggerSpy.new)
    images.add(an_image)

    spares.warm(image_name: an_image)

    assert_equal [an_image], images.names
  end

  private

  # Which image a spare was made from matters to one test only, so the tests
  # say the role rather than the name. an_image is whichever image the OS
  # under test builds its manifests around.
  def an_image
    image_name
  end

  def a_different_image
    'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a'
  end

  # Comfortably more than one run can need a container for, so a claim in a
  # test that is not about age is never declined for age.
  def outlives_a_run
    100
  end

  # Comfortably less, so a claim always is.
  def dies_under_a_run
    5
  end

  # Puts a spare in the pool with that much of its sleep still to run, and
  # answers its container id so a test can say which spare came back without
  # naming one.
  def add_spare(image_name:, seconds_left:)
    container_id = context.random.hex8
    spares.add(image_name: image_name, container_id: container_id,
               expires_at: clock.now + seconds_left)
    container_id
  end

  # As many spares as the node is allowed, so a warm has no room for another.
  def a_full_node
    SparePool::SPARES_PER_NODE
  end

  # None at all, so a warm has room.
  def an_empty_node
    0
  end

  # A daemon saying the node already holds that many spares, and answering a
  # container create with this id, and then a start.
  def daemon_holding(node_spares, creating: nil)
    DockerDaemonSpy.new([
                          [200, containers_json(node_spares)],
                          [201, %({"Id":"#{creating}"})],
                          [204, '']
                        ])
  end

  # A daemon with room on the node that refuses the create with this code,
  # which is what says whether the refusal was about the image or about
  # something else.
  def daemon_refusing_create(code, body)
    DockerDaemonSpy.new([[200, containers_json(an_empty_node)], [code, body]])
  end

  # As GET /containers/json answers it. Only how many there are matters here,
  # so they differ only by the tail of the name that keeps them apart.
  def containers_json(count)
    JSON.generate(
      Array.new(count) do |n|
        { 'Id' => format('%<n>012x', n: n),
          'Names' => [format('/cyber_dojo_spare_%<n>08x', n: n)],
          'State' => 'running' }
      end
    )
  end
end
