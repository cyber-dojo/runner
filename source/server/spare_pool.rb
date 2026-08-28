require 'json'
require_relative 'cyber_dojo_sh_container_config'
require_relative 'cyber_dojo_sh_runner'

# The spares one worker holds, keyed by the image they were made from.
#
# A spare is a container that has only ever run sleep. It serves exactly one
# exec and is then discarded, so nothing is recycled and there is nothing for
# a claim to reset: one test-run, one container.
#
# In-process and mutex-guarded, the way Puller holds @pulled. A claim happens
# on the test-run, and taking time off a test-run is the point of holding
# spares at all, so a claim asks the daemon nothing.
class SparePool
  # How many spares the node may hold, across every image and every worker on
  # it. An idle container costs about 12MB, so this is what the pool costs the
  # node when it is full.
  #
  # The cap is the node's rather than each worker's because a worker cannot
  # see how many peers it has: puma forks one per processor, but how many
  # runner pods kubernetes placed on the node is invisible from inside one.
  # So there is no divisor, and the daemon is asked instead.
  SPARES_PER_NODE = 8

  # Every spare's name starts with this, so that one filter counts all of them
  # however many workers made them. What follows it keeps two workers apart.
  SPARE_NAME_PREFIX = 'cyber_dojo_spare_'.freeze

  def initialize(context)
    @context = context
    @spares = Hash.new { |hash, image_name| hash[image_name] = [] }
    @mutex = Mutex.new
  end

  # Answers a spare's container id, or nil when this worker holds none for the
  # image that can still serve a whole run. Nil is a miss, and a miss is a
  # test-run creating its own container exactly as one does with no pool
  # behind it at all.
  def claim(image_name:)
    @mutex.synchronize do
      queue = @spares[image_name]
      # A spare too near its expiry is dropped rather than left to be
      # considered again, so one dying spare costs a claim nothing but the
      # looking.
      queue.shift while queue.any? && !usable?(queue.first)
      spare = queue.shift
      spare&.fetch(:container_id)
    end
  end

  # Takes a spare this worker has made into the pool. expires_at is when its
  # sleep ends, which is what claim measures against: the caller knows both
  # the clock it was created against and how long it was told to sleep for.
  def add(image_name:, container_id:, expires_at:)
    @mutex.synchronize do
      @spares[image_name] << { container_id: container_id, expires_at: expires_at }
    end
  end

  # Makes a spare for the image and puts it in the pool, on a thread, so that
  # whatever asked for one waits for neither the create nor the start.
  def warm(image_name:)
    threader.thread('warms-spare') do
      next if node_is_full?

      expires_at = clock.now + CyberDojoShContainerConfig::SLEEP_SECONDS
      container_id = create(image_name)
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

  # Creates the container and answers its id. Its config depends on the image
  # alone, which is what lets it be made before the run it will serve is known.
  def create(image_name)
    config = CyberDojoShContainerConfig.image_config(image_name)
    _code, body = docker.create_container(config, name: spare_name)
    JSON.parse(body)['Id']
  end

  def spare_name
    "#{SPARE_NAME_PREFIX}#{@context.random.hex8}"
  end

  # A spare has to outlive the run it is given to. An exec does not survive
  # its container's PID 1, so a sleep ending under a run kills the kata part
  # way and answers the learner faulty for a kata that was fine.
  # See docs/profiling/check_spare_sleep_ending_under_a_run.sh
  def usable?(spare)
    (spare[:expires_at] - clock.now) >= longest_hold_seconds
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

  def docker
    @context.docker
  end

  def threader
    @context.threader
  end
end
