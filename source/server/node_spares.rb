require 'digest'
require 'fileutils'

# Which spares this node holds, as one file per spare in a directory.
#
# A spare is a container on one docker daemon, so the processes that can use a
# spare are exactly those sharing the daemon's socket, which are exactly those
# sharing a kernel. The store reaches as far as that and no further, which is
# why a directory on the node is the right place to keep it: every worker on
# the node reads the same one, and a worker on another node could not use what
# it found there anyway.
#
# The directory must be on a local filesystem. Over NFS an unlink is not the
# winner-takes-all operation a claim depends on, and a second host would be a
# second kernel. That is the one way this can be broken from outside the code.
class NodeSpares
  # Where the store is: the container's own /tmp, which every puma worker in
  # it sees and which is created and destroyed with the container, so nothing
  # in it can outlive the containers it names.
  DIR = '/tmp/cyber_dojo_spares'.freeze

  def initialize(dir:)
    @dir = dir
  end

  # Answers a spare's container id, or nil when the store holds none for the
  # image whose sleep ends inside the window. Nil is a miss, and a miss is a
  # test-run creating its own container exactly as one does with no pool
  # behind it at all.
  #
  # The window is the caller's, because what a spare has to outlive is a run,
  # and the store knows nothing about runs. Its near edge keeps out a spare
  # that would die part way through the run it was given to.
  #
  # Taking the spare is unlinking its file, and that is also what makes the
  # claim exclusive: unlink is winner-takes-all, so of several processes going
  # for one spare exactly one is told it took it. Nothing here is locked, and
  # the daemon is not asked anything.
  #
  # A spare outside the window is unlinked too, as it is passed over, so a
  # later claim does not look at it again. Dropping one and taking one are
  # the same operation, which is why there is only the one unlink.
  def claim(image_name:, expiring_between:)
    dir = image_dir(image_name)
    names(image_name).each do |name|
      next unless taken?(File.join(dir, name))

      return container_id_in(name) if expiring_between.cover?(expires_at_in(name))
    end
    nil
  end

  # Takes a spare the caller has made into the store. expires_at is when its
  # sleep ends, as a monotonic reading, which is what a claim measures a spare
  # against. The caller knows both the clock it was created against and how
  # long it was told to sleep for.
  #
  # The file is empty. Its name carries the whole record, so a claim reads no
  # file at all, and there is no half-written one for a claim to read.
  def add(image_name:, container_id:, expires_at:)
    dir = image_dir(image_name)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, entry_name(expires_at, container_id)), '')
  end

  # Drops every spare, of every image, whose sleep ends outside the window.
  #
  # A claim drops what it passes over, but it only ever looks at the image it
  # was asked for. So the spares of an image nobody asks for again are never
  # passed over and never dropped, and without this the store would grow by
  # one entry for every spare ever made.
  #
  # Whoever sweeps waits on nothing, so this can afford to walk the whole
  # store where a claim can only afford one directory.
  def sweep(keeping:)
    image_dirs.each do |dir|
      names_in(dir).each do |name|
        next if keeping.cover?(expires_at_in(name))

        taken?(File.join(dir, name))
      end
    end
  end

  private

  # Every directory the store has made, one per image it has held a spare
  # for. Answers none before any warm has added anything.
  def image_dirs
    Dir.children(@dir).map { |name| File.join(@dir, name) }
  rescue SystemCallError
    []
  end

  # One spare's filename, holding when its sleep ends and which container it
  # is. Whole milliseconds, so there is no point to put a separator through.
  #
  # Zero padded to a fixed width, because a name sorts as text: unpadded,
  # 1000040000 sorts before 999999000 and a claim hands out the spare with
  # more of its sleep left, leaving the one nearest expiry to expire unused.
  # Fifteen digits is more than a machine's uptime in milliseconds can reach.
  #
  # Rounded down rather than to nearest, so the expiry written is never later
  # than the one given. A spare warmed and claimed in the same millisecond
  # sits exactly on the far edge of the window, and rounding it up by half a
  # millisecond puts it outside and refuses a spare that was fine. Down is
  # also the safe direction at the near edge, where it can only make a spare
  # look nearer its expiry than it is.
  def entry_name(expires_at, container_id)
    format('%<expiry>015d-%<id>s', expiry: (expires_at * 1000).floor, id: container_id)
  end

  # Whether this call is the one that took the entry. unlink is
  # winner-takes-all, so of several workers reaching for one spare exactly one
  # is answered true and the losers are told it is not there.
  #
  # A false is therefore this worker losing a race, and the spare it lost is
  # one another worker is already running. Answering rather than raising is
  # what keeps that off the learner's path: a claim that raised would reach
  # them as faulty, for a kata that was fine.
  def taken?(path)
    File.unlink(path)
    true
  rescue SystemCallError
    false
  end

  # Which container the name names.
  def container_id_in(name)
    name.split('-').last
  end

  # When the spare the name names ends its sleep, as the monotonic reading
  # add was given. Milliseconds in the name and seconds out, because seconds
  # are what the reading it is compared against is in.
  def expires_at_in(name)
    name.split('-').first.to_i / 1000.0
  end

  # The names of the spares the store holds for the image, nearest expiry
  # first. Sorted because a directory is not ordered, and sorting the names
  # is sorting by expiry: that is what the fixed-width expiry in front of
  # each name is for.
  #
  # Answers none for an image no warm has reached, whose directory is
  # therefore not there: a question that cannot be answered is not a spare.
  def names(image_name)
    names_in(image_dir(image_name))
  end

  # The names one directory holds, nearest expiry first.
  def names_in(dir)
    Dir.children(dir).sort
  rescue SystemCallError
    []
  end

  # Where this image's spares are kept. A digest because an image_name carries
  # characters a directory name cannot, and because mapping two of them onto
  # one name would hand a test-run a container of the wrong image, which is a
  # wrong answer rather than a slow one.
  def image_dir(image_name)
    File.join(@dir, Digest::SHA256.hexdigest(image_name))
  end
end
