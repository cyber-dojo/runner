require 'json'
require_relative 'lib/synchronized_set'
require_relative 'docker_image_name'

# Which images this node holds, as this worker believes it. A test-run may
# only go ahead for an image the node has, so this is what gates one, and
# pulling is how an image it does not have is made ready.
class NodeImages
  def initialize(context)
    @context = context
    @pulled  = SynchronizedSet.new
    @pulling = SynchronizedSet.new
  end

  def names
    @pulled.to_a
  end

  # Believes every image the daemon says the node holds. config.ru calls this
  # once at boot, so most of what is believed was never pulled by this process:
  # it is a snapshot of what was there when puma started, and an image removed
  # after that leaves no trace in it.
  #
  # It raises rather than carrying on, because a server that could not learn
  # what the node holds would answer pulling to every test-run and pull every
  # image again.
  def seed
    names_on_the_node.each { |image_name| add(image_name) }
  end

  def add(image_name)
    @pulled.add(image_name)
  end

  # Drops the belief that image_name is on the node, so the next pull pulls it
  # rather than answering :pulled. What @pulled holds is a belief: config.ru
  # seeds it from the node's images at boot, and an image removed after that
  # leaves no trace in it.
  def forget(image_name)
    @pulled.delete(image_name)
  end

  # Whether a test-run may go ahead for this image, and if it may not, starts
  # making it so. Answers :pulled or :pulling.
  def pull(id:, image_name:)
    ::DockerImageName.assert_versioned(image_name)
    image_name = ::DockerImageName.tagged(image_name)
    if @pulled.include?(image_name)
      :pulled
    else
      if @pulling.add?(image_name)
        threader.thread('pulls-image') do
          threaded_pull(id, image_name)
        end
      end
      :pulling
    end
  end

  private

  # What the daemon says is on the node, by name. One image can carry several
  # RepoTags, and an image carrying none names nothing a manifest could hold,
  # so flattening is all the filtering needed.
  def names_on_the_node
    code, body = docker.image_names
    raise body.to_s unless code == 200

    JSON.parse(body).flat_map { |image| image['RepoTags'] }.sort
  end

  def threaded_pull(id, image_name)
    # Against the clock rather than Time.now, which ntp can step under a pull
    # long enough for that to matter, and which a test cannot say anything
    # about. See MonotonicClock.
    t0 = clock.now
    # This blocks until the pull ends, which is what running on its own thread
    # allows.
    code, body = docker.pull_image(image_name)
    # Read before the branch, so what is timed is the pull and nothing else.
    # stream_error? walks the body a line at a time parsing each one, which is
    # work of this process rather than of the transfer.
    took = clock.now - t0
    if pulled?(code, body)
      add(image_name)
      logger.log(pulled_message(image_name, took))
    else
      logger.log(failed_message(id, image_name, code, body))
    end
  ensure
    @pulling.delete(image_name)
  end

  # Whether the image is now on the node. A 200 is not enough on its own,
  # which stream_error? below says why.
  def pulled?(code, body)
    code == 200 && !stream_error?(body)
  end

  # A tenth of a second is as fine as anyone reading a log needs.
  def pulled_message(image_name, took)
    "Pulled docker image #{image_name} (#{took.round(1)} secs)"
  end

  # The id names the kata whose creation asked for this image, which is what
  # ties a failed pull to the person about to be told the runner is pulling. A
  # pull that worked needs no such tie: the image is there, and every later
  # kata on it benefits.
  def failed_message(id, image_name, code, body)
    "Failed to pull docker image #{image_name}, id=#{id}, code=#{code}, body=#{body}"
  end

  # The daemon sends its status code before the transfer begins, so a pull it
  # starts and cannot finish is a 200 whose newline-delimited stream carries
  # an error object. The stream ends with a newline, hence the blank line.
  def stream_error?(body)
    body.each_line.any? do |line|
      stripped = line.strip
      !stripped.empty? && JSON.parse(stripped).key?('error')
    end
  end

  def clock
    @context.clock
  end

  def logger
    @context.logger
  end

  def docker
    @context.docker
  end

  def threader
    @context.threader
  end
end
