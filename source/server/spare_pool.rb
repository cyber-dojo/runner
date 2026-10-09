require 'json'
require_relative 'cyber_dojo_sh_container_config'
require_relative 'cyber_dojo_sh_runner'

# The policy for the node's spares: what may be claimed, how many there may
# be, and what making one costs.
#
# A spare is a container that has only ever run sleep. It serves exactly one
# exec and is then discarded, so nothing is recycled and there is nothing for
# a claim to reset: one test-run, one container.
#
# The spares themselves are NodeSpares', in a directory every worker on the
# node reads, so a spare one worker warmed is one any of them can claim. This
# holds no spare of its own, and nothing it knows is lost when a worker dies.
#
# A claim happens on the test-run, and taking time off a test-run is the point
# of holding spares at all, so a claim asks the daemon nothing. It costs one
# directory listing and one unlink, which
# docs/profiling/time_claim_from_a_shared_directory.rb prices at 0.0062ms
# against the 25.6ms the same question costs the daemon.
#
# A claim takes the spare nearest its expiry that can still serve a whole
# test-run. That spends spares before they expire, because a spare nobody
# claims expires and the create that made it bought nothing. One too near its
# expiry is dropped rather than handed out.
class SparePool
  # How many spares the node may hold, across every image and every worker on
  # it. An idle container costs up to about 12MB, so a full pool costs the node
  # up to 12MB * SPARES_PER_NODE.
  #
  # 12MB is the safe end of a range rather than a figure. The container's own
  # use is under 1MB, which two runs of
  #   docs/profiling/measure_idle_warm_container_cost.sh <image_name>
  # agree on: 708KB and 776KB. The rest is the shim and the daemon's
  # bookkeeping, and that is read from MemAvailable, which moves with how much
  # the host has free. The same probe on the same machine answered about 12MB
  # each with 7.4GB available and about 5.2MB each with 5.7GB available.
  # Budget against the larger, because a cap sized on the smaller overruns.
  #
  # The cap is the node's rather than each worker's because a worker cannot
  # see how many peers it has. puma forks one per processor, and however many
  # runner processes the node is running is invisible from inside one of them.
  #
  # What every one of them does share is the daemon socket, bind-mounted from
  # the host, so the daemon holds every spare on the node however many runners
  # made them. That is true of any way of running the server. So there is no
  # divisor, and the daemon is asked instead.
  SPARES_PER_NODE = 16

  # Every spare's name starts with this, so that one filter counts all of them
  # however many workers made them. What follows it keeps two workers apart.
  SPARE_NAME_PREFIX = 'cyber_dojo_spare_'.freeze

  def initialize(context)
    @context = context
  end

  # Answers a spare's container id, or nil when the node holds none for the
  # image that can still serve a whole run. Nil is a miss, and a miss is a
  # test-run creating its own container exactly as one does with no pool
  # behind it at all.
  #
  # A claimed spare is renamed to the name its test-run runs under, so that a
  # container serving a run is named the same whether it came from the pool or
  # was made for the run. That is what lets docker ps say which kata a
  # container is serving, and what takes the container out of the count the cap
  # reads.
  #
  # On a thread, so the claim itself waits for no daemon call. Exclusivity is
  # the unlink's, not the rename's, so nothing depends on when the rename
  # lands: the count is a target rather than a ceiling, and a window where it
  # still counts a claimed container is the kind of looseness it is built for.
  def claim(image_name:, container_name:)
    container_id = node_spares.claim(image_name: image_name,
                                     expiring_between: usable_window)
    return nil if container_id.nil?

    threader.thread('renames-spare') do
      docker.rename_container(container_id, name: container_name)
    end
    container_id
  end

  # Takes a spare this worker has made into the pool. expires_at is when its
  # sleep ends, which is what claim measures against: the caller knows both
  # the clock it was created against and how long it was told to sleep for.
  def add(image_name:, container_id:, expires_at:)
    node_spares.add(image_name: image_name, container_id: container_id,
                    expires_at: expires_at)
  end

  # Makes a spare for the image and puts it in the pool, on a thread, so that
  # whatever asked for one waits for neither the create nor the start.
  def warm(image_name:)
    threader.thread('warms-spare') do
      # Before the cap is read, so a spare whose sleep has ended is not
      # counted as one the node is holding.
      node_spares.sweep(keeping: unexpired)
      next if node_is_full?

      expires_at = clock.now + CyberDojoShContainerConfig::SLEEP_SECONDS
      container_id = create(image_name)
      next if container_id.nil?

      docker.start_container(container_id)
      add(image_name: image_name, container_id: container_id, expires_at: expires_at)
    end
  end

  private

  # Whether the node already holds as many spares as it is allowed. The count
  # comes from the daemon because the cap is the node's, and the daemon is the
  # only thing that can see every worker's spares.
  #
  # It counts by name rather than by label. A claimed container keeps the label
  # it was created with, labels being unchangeable after a create, and both a
  # spare and a container serving a run are merely running. Counting labels
  # would therefore count runs in flight, and the pool would stop refilling
  # under exactly the load it exists for. A claim renames instead, which takes
  # the container out of this count.
  #
  # Two workers can both read one short of the cap and both create, so this is
  # a target rather than a ceiling. The overshoot is bounded by how many are
  # creating at once and costs about 12MB each, which is the right thing to be
  # loose about.
  def node_is_full?
    _code, body = docker.containers_named(SPARE_NAME_PREFIX)
    JSON.parse(body).size >= SPARES_PER_NODE
  end

  # Creates the container and answers its id, or nil when the daemon refuses.
  # Its config depends on the image alone, which is what lets it be made
  # before the run it will serve is known.
  #
  # Nil rather than raising, because warming happens on a thread nobody is
  # waiting on: an exception there would go nowhere, so the log is the only
  # place the refusal can be reported.
  #
  # A 404 says the image has left the node, which is the one refusal that says
  # anything about the image at all, so it is forgotten here as the run path
  # forgets it. Noticing it here is noticing it earlier: at warm time no
  # learner has been shown anything yet, where the run path's 404 has already
  # cost one faulty light. Every other status says nothing about the image, a
  # taken container name for instance, and leaves it believed present.
  def create(image_name)
    config = CyberDojoShContainerConfig.image_config(image_name)
    code, body = docker.create_container(config, name: spare_name)
    return JSON.parse(body)['Id'] if code.between?(200, 299)

    logger.log("Failed to warm docker image #{image_name}, code=#{code}, body=#{body}")
    images.forget(image_name) if code == CyberDojoShRunner::DaemonRefused::NO_SUCH_IMAGE
    nil
  end

  def spare_name
    "#{SPARE_NAME_PREFIX}#{@context.random.hex8}"
  end

  # When a spare this pool will claim ends its sleep.
  #
  # Its near edge is what a spare has to outlive: an exec does not survive its
  # container's PID 1, so a sleep ending under a run kills the kata part way
  # and answers the learner faulty for a kata that was fine.
  # See docs/profiling/check_spare_sleep_ending_under_a_run.sh
  #
  # Its far edge is one whole sleep, which is as far off as a spare this pool
  # warmed can be: warm reads the clock before it creates. Anything beyond it
  # was written against a clock of another origin, so the store outlived the
  # boot whose containers it names and every one of them is gone.
  def usable_window
    now = clock.now
    (now + longest_hold_seconds)..(now + CyberDojoShContainerConfig::SLEEP_SECONDS)
  end

  # What a sweep keeps: every spare with enough sleep left to serve a run.
  #
  # Open at the top where usable_window is not. A spare another worker warmed
  # sits on that worker's far edge, and a sweep measuring against a clock it
  # read a moment earlier would put that spare outside its own far edge and
  # throw away work that was fine. Nothing above the near edge is ever swept,
  # so no race can cost a spare.
  #
  # An expiry further off than a whole sleep is left to a claim, which
  # refuses it and unlinks it as it passes over.
  def unexpired
    (clock.now + longest_hold_seconds)..Float::INFINITY
  end

  # The longest one run can hold a container: the cap on a kata, and the grace
  # a stop allows its EXIT trap. Both are read from the runner that imposes
  # them, so raising either cannot leave this believing the old one.
  #
  # Nothing is added for the exec setup between the claim and the deadline
  # starting, which is measured in milliseconds. What that leaves is about a
  # second of slack on the only span that matters, the payload read, and the
  # read cannot overrun its cap because the deadline stops it.
  def longest_hold_seconds
    CyberDojoShRunner::RUN_SECONDS + CyberDojoShRunner::STOP_SECONDS
  end

  def clock
    @context.clock
  end

  def node_spares
    @context.node_spares
  end

  def docker
    @context.docker
  end

  def images
    @context.images
  end

  def logger
    @context.logger
  end

  def threader
    @context.threader
  end
end
