require_relative '../test_base'
require_code 'node_spares'

class NodeSparesTest < TestBase

  test 'k4Wp71', %w(
  | Nothing has ever added a spare, so the store's directory is not there.
  | A claim answers nil, which is a miss.
  | A test-run meeting a store no warm has reached yet creates its own
  | container, exactly as one does with no pool behind it at all.
  ) do
    assert_nil node_spares.claim(image_name: an_image, expiring_between: a_window)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k4Wp72', %w(
  | A warm has added one spare for the image_name.
  | A claim answers the container id that warm added.
  | The claim is made through a second store object on the same directory.
  | So what one worker warmed is what another worker claims.
  ) do
    node_spares.add(image_name: an_image, container_id: a_container_id,
                    expires_at: outlives_a_run)

    assert_equal a_container_id,
                 node_spares.claim(image_name: an_image, expiring_between: a_window)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k4Wp73', %w(
  | The store holds one spare for the image_name.
  | A claim answers it and takes it out of the store.
  | A spare serves exactly one exec and is then discarded.
  | So the next claim answers nil rather than the same container again.
  ) do
    node_spares.add(image_name: an_image, container_id: a_container_id,
                    expires_at: outlives_a_run)

    assert_equal a_container_id,
                 node_spares.claim(image_name: an_image, expiring_between: a_window)
    assert_nil node_spares.claim(image_name: an_image, expiring_between: a_window)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k4Wp74', %w(
  | The store holds one spare, made from one image_name, and nothing else.
  | A claim for a different image_name answers nil.
  | A claim for the image_name the spare was made from answers it.
  | So the nil came from the image_names differing, not from an empty store.
  | A spare only fits the image it was made from: its language and its
  | test-framework are the image's, so another image's run cannot use it.
  ) do
    node_spares.add(image_name: a_different_image, container_id: a_container_id,
                    expires_at: outlives_a_run)

    assert_nil node_spares.claim(image_name: an_image, expiring_between: a_window)
    assert_equal a_container_id,
                 node_spares.claim(image_name: a_different_image, expiring_between: a_window)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k4Wp75', %w(
  | The store holds a spare whose sleep ends before the window opens.
  | A spare has to outlive the run it is given to.
  | An exec does not survive its container's PID 1, which is the sleep.
  | A sleep ending under a run kills the kata part way and answers the
  | learner faulty for a kata that was fine.
  | So the claim answers nil.
  | See docs/profiling/check_spare_sleep_ending_under_a_run.sh
  ) do
    node_spares.add(image_name: an_image, container_id: a_container_id,
                    expires_at: dies_under_a_run)

    assert_nil node_spares.claim(image_name: an_image, expiring_between: a_window)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k4Wp76', %w(
  | The store holds a spare whose sleep ends before the window opens.
  | A claim passes over it, and drops it as it goes.
  | A later claim, whose window is wide enough to have taken it, answers nil.
  | So the first claim dropped it rather than leaving it to be looked at
  | again by every claim after it.
  ) do
    node_spares.add(image_name: an_image, container_id: a_container_id,
                    expires_at: dies_under_a_run)

    assert_nil node_spares.claim(image_name: an_image, expiring_between: a_window)
    assert_nil node_spares.claim(image_name: an_image,
                                 expiring_between: a_window_taking_any_expiry)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k4Wp77', %w(
  | The store holds a spare whose sleep ends after the window closes.
  | No spare a warm made can be that far off: a warm reads the clock before
  | it creates, so a spare's expiry is less than one whole sleep away.
  | One further off than that was written against a clock of another origin,
  | which is a store that outlived the boot whose containers it names.
  | Every container it names is gone, so the claim answers nil.
  ) do
    node_spares.add(image_name: an_image, container_id: a_container_id,
                    expires_at: outlives_every_sleep)

    assert_nil node_spares.claim(image_name: an_image, expiring_between: a_window)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k4Wp78', %w(
  | The store holds two spares for one image_name, both inside the window.
  | The first has less of its sleep left than the one behind it.
  | A spare nobody claims expires, and the create that made it bought nothing.
  | The one nearest its expiry is the one most at risk of that.
  | So a claim answers it, and the claim after answers the one behind it.
  | Their millisecond counts differ in width, one either side of a power of
  | ten, because a name sorts as text and only a fixed width makes that sort
  | agree with the number.
  ) do
    node_spares.add(image_name: an_image, container_id: another_container_id,
                    expires_at: expires_later)
    node_spares.add(image_name: an_image, container_id: a_container_id,
                    expires_at: expires_sooner)

    assert_equal a_container_id,
                 node_spares.claim(image_name: an_image,
                                   expiring_between: a_window_taking_any_expiry)
    assert_equal another_container_id,
                 node_spares.claim(image_name: an_image,
                                   expiring_between: a_window_taking_any_expiry)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k4Wp79', %w(
  | A spare's whole record is its filename.
  | add writes no bytes into the file it makes.
  | So a claim reads no file at all: it lists a directory and unlinks a name.
  | It also means there is no half-written file for a claim to read.
  ) do
    node_spares.add(image_name: an_image, container_id: a_container_id,
                    expires_at: outlives_a_run)

    assert_equal [0], sizes_of_every_file_in_the_store
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k4Wp710', %w(
  | Two workers list one spare, and the other worker unlinks it first.
  | This one's unlink finds it gone, which is how it learns it lost.
  | It passes over the spare rather than raising.
  | A claim that raised would reach the learner as faulty, for a kata that
  | was fine, which is the one thing the pool may never cost.
  | So the claim answers nil, and a miss is all a lost race costs.
  ) do
    store = LosesEveryRace.new(dir: "/tmp/#{id}")
    store.add(image_name: an_image, container_id: a_container_id,
              expires_at: outlives_a_run)

    assert_nil store.claim(image_name: an_image, expiring_between: a_window)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k4Wp711', %w(
  | A warm in one process adds a spare.
  | A claim in another process, sharing none of its memory, answers it.
  | The two agree through the directory and through nothing else.
  | This is what the store is for: a spare one puma worker warmed is one any
  | worker on the node can claim, where an in-process queue reaches only the
  | worker that filled it.
  | The spare is gone from this process too, so one container still serves
  | exactly one test-run however many processes are reaching for it.
  ) do
    node_spares.add(image_name: an_image, container_id: a_container_id,
                    expires_at: outlives_a_run)

    assert_equal a_container_id, claimed_in_another_process
    assert_nil a_claim
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k4Wp712', %w(
  | The store holds a spare outside the window, for one image_name, and one
  | inside it for another.
  | A claim only ever looks at the image it was asked for, so the spares of
  | an image nobody asks for again are never passed over and never dropped.
  | A sweep drops every spare outside the window, whatever image it is for.
  | The spare inside the window is left, and a claim still answers it.
  ) do
    node_spares.add(image_name: a_different_image, container_id: another_container_id,
                    expires_at: dies_under_a_run)
    node_spares.add(image_name: an_image, container_id: a_container_id,
                    expires_at: outlives_a_run)

    node_spares.sweep(keeping: a_window)

    assert_nil node_spares.claim(image_name: a_different_image,
                                 expiring_between: a_window_taking_any_expiry)
    assert_equal a_container_id,
                 node_spares.claim(image_name: an_image, expiring_between: a_window)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k4Wp713', %w(
  | Nothing has ever added a spare, so the store's directory is not there.
  | A sweep drops nothing and does not raise.
  | A sweep runs on the thread that warms, which nobody waits on, so one
  | that raised would go unreported and take the warm down with it.
  ) do
    node_spares.sweep(keeping: a_window)

    assert_nil a_claim
  end

  private

  # What a claim made in another process answers. A fork, so that nothing in
  # this process's memory can be what carries the spare across: the child has
  # its own copy of all of it and the directory is the only thing they share.
  #
  # The answer comes back through a file, a fork carrying nothing back but an
  # exit status. exit! rather than exit, so the child runs none of this
  # process's at_exit handlers and SimpleCov writes no second set of results.
  #
  # The child's whole body is on the fork's own line. A forked child reports
  # no coverage back, so a block spread over several lines leaves every one
  # of them looking unreached, where the one line the parent calls fork on is
  # a line the parent ran.
  def claimed_in_another_process
    answer = "/tmp/#{id}.answer"
    pid = fork { File.write(answer, a_claim.to_s) && exit!(0) }
    Process.waitpid(pid)
    File.read(answer)
  end

  # A claim from this test's store, for the window every test here uses.
  # Both this process and a forked child make the same one, which is what
  # lets the two be compared.
  def a_claim
    node_spares.claim(image_name: an_image, expiring_between: a_window)
  end

  # A store that loses every race: each spare it lists has been taken by
  # another worker by the time it reaches for it.
  #
  # A subclass rather than two real processes, because with real ones the
  # loser may do its listing after the winner has already unlinked, and so
  # never reach for a spare at all. That would make what this test covers a
  # matter of timing, and a coverage gate cannot be held to a race.
  class LosesEveryRace < NodeSpares
    private

    # The names, with every file behind them already unlinked.
    def names(image_name)
      super.each { |name| File.unlink(File.join(image_dir(image_name), name)) }
    end
  end

  # The size of every file the store has written, found by walking the store
  # rather than by rebuilding a path, so this says nothing about how the
  # store lays its directories out.
  def sizes_of_every_file_in_the_store
    Dir.glob("/tmp/#{id}/**/*").select { |path| File.file?(path) }.map { |path| File.size(path) }
  end

  # A store under a directory this test alone uses. Built from id rather than
  # id58 because multi_os variants share an id58 and run in parallel, so two
  # of them would otherwise claim from one another's store.
  #
  # A new object each call, standing for a different worker each time. Two
  # that agree are agreeing through the directory, because there is nothing
  # else for them to agree through.
  def node_spares
    NodeSpares.new(dir: "/tmp/#{id}")
  end

  # Which image a spare was made from matters to one test only, so the tests
  # say the role rather than the name. an_image is whichever image the OS
  # under test builds its manifests around.
  def an_image
    image_name
  end

  # An image_name that is not an_image, and is a real start-point's, so that
  # the two differ the way two start-points differ rather than by invention.
  def a_different_image
    'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a'
  end

  # As the daemon answers one, which is the hex id of a container that exists.
  def a_container_id
    '7c1e04d9'
  end

  # A monotonic reading standing for the clock a claim reads. Its origin is
  # the machine booting, so a reading says nothing alone and everything
  # beside another, which is why every expiry below is written against it.
  NOW = 1_000_000.0

  # The expiries a claim accepts: at least a whole test-run away, so the
  # spare outlives the run it is given to, and no further off than a whole
  # sleep, so a reading written against another boot's clock falls outside.
  # SparePool reads both bounds from the runner that imposes them.
  def a_window
    (NOW + 16.0)..(NOW + 60.0)
  end

  # An expiry comfortably inside the window, so a claim in a test that is not
  # about age is never declined for age.
  def outlives_a_run
    NOW + 50.0
  end

  # An expiry before the window opens, so a claim always is.
  def dies_under_a_run
    NOW + 5.0
  end

  # An expiry beyond the window's far edge, further off than a whole sleep,
  # which is where a reading written against another boot's clock lands.
  def outlives_every_sleep
    NOW + 600.0
  end

  # A window holding every expiry above, so a claim made with it answers nil
  # only when the store has nothing left, never because of age.
  def a_window_taking_any_expiry
    (NOW - 1000.0)..(NOW + 1000.0)
  end

  # Two expiries, the nearer one just under a whole number of seconds that
  # makes its millisecond count one digit shorter than the other's. An entry
  # sorts as text, so unpadded the longer one sorts first and a claim hands
  # out the spare with more of its sleep left, leaving the other to expire.
  def expires_sooner
    NOW - 1.0
  end

  def expires_later
    NOW + 40.0
  end

  # A second container id, so a test holding two spares can say which came
  # back without either standing for both.
  def another_container_id
    'b52f8a30'
  end
end
