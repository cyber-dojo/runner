require 'json'
require_relative 'synchronized_set'
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

  def threaded_pull(_id, image_name)
    t0 = Time.now
    # This blocks until the pull ends, which is what running on its own thread
    # allows.
    code, body = docker.pull_image(image_name)
    if code == 200 && !stream_error?(body)
      t1 = Time.now
      add(image_name)
      took = (t1 - t0).round(1)
      logger.log("Pulled docker image #{image_name} (#{took} secs)")
    else
      logger.log("Failed to pull docker image #{image_name}, code=#{code}, body=#{body}")
    end
  ensure
    @pulling.delete(image_name)
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
