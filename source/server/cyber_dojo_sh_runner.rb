require 'json'
require_relative 'cyber_dojo_sh_container_config'
require_relative 'deadline_reader'
require_relative 'docker_attach_frames'

# Runs one cyber-dojo.sh in a container, over the docker daemon's socket.
# Answers what the container sent back, and whether it ran out of time.
#
# There is no exit status in the answer. The container is created with
# AutoRemove, so it is gone the moment it exits and there is nothing left to
# ask; and a payload that parses and holds tmp/status is itself proof the run
# was fine. A payload that does not parse is faulty however the container
# exited.
class CyberDojoShRunner
  # The daemon would not do what it was asked. Carrying on regardless means
  # working with no container id, or with one that never started, and failing
  # later somewhere that says nothing about why.
  #
  # It carries the status code because which refusal it is decides what the
  # runner does next, which is what ImageMissing below is about, and because
  # what the daemon said belongs in the log either way.
  class DaemonRefused < RuntimeError
    def initialize(code, message)
      @code = code
      super(message)
    end

    attr_reader :code

    NO_SUCH_IMAGE = 404
  end

  # The image is not on the node, which only a container create can discover.
  # The daemon looks for the image before it looks at anything else the create
  # asks for, so a 404 is the only status that says the image is missing.
  # Every other status it answers was reached with the image already found.
  #
  # This is the one refusal that says the runner's idea of what the node holds
  # is wrong, which is why it has a class of its own rather than a status code
  # the caller has to interpret.
  #
  # A start answers 404 too, and means something else entirely: the container
  # has gone, not the image. Reading that as an image being absent would throw
  # away a present image and pull it again for nothing.
  class ImageMissing < DaemonRefused
  end

  def initialize(context)
    @context = context
  end

  def run(id, image_name, container_name, max_seconds, tgz_in)
    container_id = create(id, image_name, container_name)
    # Attaching before starting is what stops the container's first bytes
    # being written before anything is listening for them.
    stream = docker.attach_container(container_id)
    start(container_id)
    send_tgz(stream, tgz_in)
    result_of(container_id, stream, max_seconds)
  end

  private

  def docker
    @context.docker
  end

  # Starts the container, which is what sets its cyber-dojo.sh going. A refusal
  # here leaves a container that will never write anything, so the read that
  # follows would wait out the whole deadline before answering timed_out.
  def start(container_id)
    code, body = docker.start_container(container_id)
    raise DaemonRefused.new(code, "start answered #{code}: #{body}") unless code.between?(200, 299)
  end

  # The container this run's cyber-dojo.sh runs in, created but not started.
  def create(id, image_name, container_name)
    config = CyberDojoShContainerConfig.create_config(id, image_name)
    code, body = docker.create_container(config, name: container_name)
    message = "create answered #{code}: #{body}"
    raise ImageMissing.new(code, message) if code == DaemonRefused::NO_SUCH_IMAGE
    raise DaemonRefused.new(code, message) unless code.between?(200, 299)

    JSON.parse(body)['Id']
  end

  # Shutting down the writing half is what gives the container's
  # [tar -zxf -] its end of file. Without it the container waits for one that
  # never comes, and so does whoever is reading its stdout. The reading half
  # stays open, because that is where the payload arrives.
  def send_tgz(stream, tgz_in)
    stream.write(tgz_in)
    stream.close_write
  end

  # What the container sent, or timed_out. Nothing partial is answered: what
  # arrived before the deadline passed is not a whole payload.
  def result_of(container_id, stream, max_seconds)
    stdout, stderr = read_payload(stream, max_seconds)
    { timed_out: false, stdout: stdout, stderr: stderr }
  rescue DeadlineReader::Expired
    # Stopping the container is what ends a timed-out run: its cyber-dojo.sh is
    # still going, so nothing else would. One second is enough for that
    # script's own EXIT trap to get its chance before the SIGKILL, and
    # AutoRemove then disposes of the container.
    docker.stop_container(container_id, seconds: 1)
    { timed_out: true, stdout: '', stderr: '' }
  end

  # The deadline starts once the container has everything it needs, and bounds
  # the whole read rather than each part of it.
  def read_payload(stream, max_seconds)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + max_seconds
    DockerAttachFrames.demultiplex(DeadlineReader.new(stream, deadline))
  end
end
