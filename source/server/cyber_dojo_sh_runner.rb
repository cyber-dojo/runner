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
  # working with no container or exec id, and failing later somewhere that
  # says nothing about why. It carries the status code so that what the daemon
  # said reaches the log.
  class DaemonRefused < RuntimeError
    def initialize(code, message)
      @code = code
      super(message)
    end

    attr_reader :code

    NO_SUCH_IMAGE = 404
  end

  # The image is not on the node, which only a container create can discover:
  # it checks the image before the name, so every other code it answers is
  # reached having already found the image. This is the one refusal that says
  # the runner's idea of what the node holds is wrong, which is why it has a
  # class of its own rather than being a code the caller has to interpret.
  #
  # An exec create answers 404 too, and means something else entirely: the
  # container has gone, not the image. Reading that as an image being absent
  # would throw away a present image and pull it again for nothing.
  class ImageMissing < DaemonRefused
  end

  # The longest a kata may run for, whatever its manifest asks for. runner.rb
  # applies it and DeadlineReader enforces it.
  RUN_SECONDS = 15

  # What a stop gives cyber-dojo.sh's own EXIT trap before the SIGKILL.
  STOP_SECONDS = 1

  def initialize(context)
    @context = context
  end

  def run(id, image_name, container_name, max_seconds, tgz_in)
    # A spare is already created and already started, which is the whole of
    # what holding one buys.
    spare = spares.claim(image_name: image_name)
    if spare
      begin
        return run_in(spare, id, max_seconds, tgz_in)
      rescue DaemonRefused
        # The spare was gone, or was no longer running. A container made for
        # this run cannot be either of those, so the learner is owed the run
        # they would have had with no pool rather than a faulty light. Nothing
        # is half-done: both exec calls come before the tgz is written.
        nil
      end
    end
    run_in(created_and_started(image_name, container_name), id, max_seconds, tgz_in)
  end

  private

  # Whatever container this run ends up with is disposed of however the run
  # ends. A refused container create is outside this, having made none to stop.
  def run_in(container_id, id, max_seconds, tgz_in)
    exec_cyber_dojo_sh(container_id, id, max_seconds, tgz_in)
  ensure
    stop(container_id)
  end

  # A container of this run's own, ready to be exec'd into: what a spare
  # already is by the time it is claimed.
  def created_and_started(image_name, container_name)
    container_id = create(image_name, container_name)
    docker.start_container(container_id)
    container_id
  end

  def docker
    @context.docker
  end

  def spares
    @context.spares
  end

  def threader
    @context.threader
  end

  # Runs cyber-dojo.sh in a container that already exists. An exec can only be
  # made in a container that is running, and starting that exec is itself what
  # hijacks the stream, so there is nothing to attach beforehand and no first
  # bytes to miss.
  def exec_cyber_dojo_sh(container_id, id, max_seconds, tgz_in)
    exec_id = create_exec(container_id, id)
    stream = docker.start_exec(exec_id)
    send_tgz(stream, tgz_in)
    result_of(stream, max_seconds)
  end

  # The container's own Cmd is a sleep, which outlives the exec that does the
  # work, so nothing else disposes of it and a run that left it would hold it
  # for the rest of that sleep. AutoRemove disposes of it once it has stopped.
  #
  # On a thread, because a learner is owed their traffic light and not a wait
  # for a teardown they cannot see. Should this process die before the thread
  # runs, the container's own sleep still ends it.
  def stop(container_id)
    threader.thread('stops-container') do
      docker.stop_container(container_id, seconds: STOP_SECONDS)
    end
  end

  # The container depends on its image alone, so nothing about this run is
  # said here. Its command sleeps, which is what keeps it there to be exec'd.
  def create(image_name, container_name)
    config = CyberDojoShContainerConfig.image_config(image_name)
    code, body = docker.create_container(config, name: container_name)
    message = "create answered #{code}: #{body}"
    raise ImageMissing.new(code, message) if code == DaemonRefused::NO_SUCH_IMAGE
    raise DaemonRefused.new(code, message) unless code.between?(200, 299)

    JSON.parse(body)['Id']
  end

  # Everything belonging to this one run rides on the exec: the command, and
  # the vars naming the run.
  def create_exec(container_id, id)
    config = CyberDojoShContainerConfig.exec_config(id)
    code, body = docker.create_exec(container_id, config)
    raise DaemonRefused.new(code, "exec create answered #{code}: #{body}") unless code.between?(200, 299)

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
  def result_of(stream, max_seconds)
    stdout, stderr = read_payload(stream, max_seconds)
    { timed_out: false, stdout: stdout, stderr: stderr }
  rescue DeadlineReader::Expired
    { timed_out: true, stdout: '', stderr: '' }
  end

  # The deadline starts once the container has everything it needs, and bounds
  # the whole read rather than each part of it.
  def read_payload(stream, max_seconds)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + max_seconds
    DockerAttachFrames.demultiplex(DeadlineReader.new(stream, deadline))
  end
end
