require_relative '../test_base'
require_code 'cyber_dojo_sh_container_config'

class SparePoolTest < TestBase

  test '7Bq2E1', %w(
  | The pool holds no spare for the image_name.
  | A claim answers nil.
  | That is a miss.
  ) do
    set_context

    assert_nil spares.claim(image_name: an_image, container_name: a_run_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E2', %w(
  | The pool holds one spare for the image_name.
  | A claim answers it, and takes it out of the pool.
  | One container serves one test-run.
  | So the next claim answers nil rather than the same container.
  ) do
    set_context
    spare = add_spare(image_name: an_image, seconds_left: outlives_a_run)

    assert_equal spare, spares.claim(image_name: an_image, container_name: a_run_name)
    assert_nil spares.claim(image_name: an_image, container_name: a_run_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E3', %w(
  | The pool holds one spare, made from one image_name, and nothing else.
  | A claim for a different image_name answers nil.
  | A claim for the image_name the spare was made from answers it.
  | So the nil came from the image_names differing, not from an empty pool.
  ) do
    set_context
    spare = add_spare(image_name: a_different_image, seconds_left: outlives_a_run)

    assert_nil spares.claim(image_name: an_image, container_name: a_run_name)
    assert_equal spare, spares.claim(image_name: a_different_image, container_name: a_run_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E4', %w(
  | The pool holds a spare that cannot outlast a whole test-run.
  | A spare has to outlive the run it is given to.
  | An exec does not survive its container's PID 1, which is the sleep.
  | So the claim answers nil.
  | See docs/profiling/check_spare_sleep_ending_under_a_run.sh
  ) do
    set_context
    add_spare(image_name: an_image, seconds_left: dies_under_a_run)

    assert_nil spares.claim(image_name: an_image, container_name: a_run_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E5', %w(
  | The pool holds two spares for one image_name.
  | The first cannot outlast a whole test-run.
  | The one behind it can.
  | A claim passes over the first and answers the one behind it.
  | The next claim answers nil.
  | The first was dropped, not left for a later claim to look at again.
  ) do
    set_context
    add_spare(image_name: an_image, seconds_left: dies_under_a_run)
    survivor = add_spare(image_name: an_image, seconds_left: outlives_a_run)

    assert_equal survivor, spares.claim(image_name: an_image, container_name: a_run_name)
    assert_nil spares.claim(image_name: an_image, container_name: a_run_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E13', %w(
  | The pool holds two spares for one image_name.
  | Both can outlast a whole test-run.
  | The first has less of its sleep left than the one behind it.
  | A spare nobody claims expires, and the create that made it bought nothing.
  | The one nearest its expiry is the one most at risk of that.
  | So a claim answers the first.
  | The next claim answers the one behind it.
  ) do
    set_context
    expires_sooner = add_spare(image_name: an_image, seconds_left: outlives_a_run_narrowly)
    expires_later = add_spare(image_name: an_image, seconds_left: outlives_a_run)

    assert_equal expires_sooner, spares.claim(image_name: an_image, container_name: a_run_name)
    assert_equal expires_later, spares.claim(image_name: an_image, container_name: a_run_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E6', %w(
  | The node has room for another spare.
  | Warming an image_name creates a container and starts it.
  | The container's config comes from the image_name alone.
  | A spare can therefore be made before the test-run it will serve is known.
  | Its name starts with the prefix every worker's spares share.
  | The warm happens on a thread.
  | Whatever asked for a spare waits for neither the create nor the start.
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
  | The node has room for another spare.
  | Warming an image_name puts the container it created into the pool.
  | A claim for that image_name answers it.
  | The expiry the warm gave it leaves room for a whole test-run.
  | So the claim is not declined for age.
  ) do
    daemon = daemon_holding(an_empty_node, creating: 'b52f8a30')
    set_context(docker: daemon, threader: ThreaderSynchronous.new)

    spares.warm(image_name: an_image)

    assert_equal 'b52f8a30', spares.claim(image_name: an_image, container_name: a_run_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E8', %w(
  | The node already holds as many spares as it is allowed.
  | A warm asks the daemon how many there are, and creates nothing.
  | The pool is given nothing, so a claim answers nil.
  | The count comes from the daemon because the cap is the node's.
  | A worker cannot see how many peers it has.
  | It counts containers whose name starts with the spare prefix.
  | A claimed container keeps the label it was created with.
  | A claim changes its name.
  | So the name is what tells a spare from a test-run in flight.
  ) do
    daemon = daemon_holding(a_full_node)
    set_context(docker: daemon, threader: ThreaderSynchronous.new)

    spares.warm(image_name: an_image)

    assert_equal [[:containers_named, 'cyber_dojo_spare_']], daemon.calls
    assert_nil spares.claim(image_name: an_image, container_name: a_run_name)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E9', %w(
  | The daemon refuses the create.
  | The warm stops there, and nothing is started.
  | The refusal is logged, with the code and the body the daemon gave.
  | Nobody is waiting on a warm.
  | So the log is the only place it can be reported.
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
  | The image_name is believed to be on the node.
  | The daemon refuses the create with a 404, which says no such image.
  | So the image_name is forgotten.
  | The run path acts on the same 404.
  | Acting on it here is acting before any learner has been shown anything.
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
  | The image_name is believed to be on the node.
  | The daemon refuses the create with a 409.
  | That says the container name is already in use.
  | A taken name says nothing about whether the image is on the node.
  | So the image_name is still believed to be there.
  ) do
    conflict = '{"message":"Conflict. The container name is already in use"}'
    set_context(docker: daemon_refusing_create(409, conflict),
                threader: ThreaderSynchronous.new, logger: StdoutLoggerSpy.new)
    images.add(an_image)

    spares.warm(image_name: an_image)

    assert_equal [an_image], images.names
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '7Bq2E12', %w(
  | The pool holds a spare.
  | A claim answers it, and renames it to the name its test-run runs under.
  | The rename is on a thread, so the claim waits for no daemon call.
  | Each test-run's container is named for that run.
  | So docker ps says which kata a container is serving.
  | The rename also takes the container out of the count the cap reads.
  ) do
    threader = ThreaderSynchronous.new
    daemon = DockerDaemonSpy.new([[204, '']])
    set_context(docker: daemon, threader: threader)
    spare = add_spare(image_name: an_image, seconds_left: outlives_a_run)

    claimed = spares.claim(image_name: an_image, container_name: a_run_name)

    assert_equal spare, claimed
    assert threader.called, 'threader'
    assert_equal [[:rename_container, spare, a_run_name]], daemon.calls
  end

  private

  # As runner.rb builds it, from the kata id and a per-run random hex8.
  def a_run_name
    "cyber_dojo_runner_#{id58}_9a3b1c7d"
  end

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

  # Also more than one run can need a container for, but well short of
  # outlives_a_run, so which of two claimable spares is nearer its expiry is
  # not in doubt.
  def outlives_a_run_narrowly
    20
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
