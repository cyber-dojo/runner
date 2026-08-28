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
  # working with no container id, and failing later somewhere that says
  # nothing about why.
  #
  # It carries the status code because which refusal it is decides what the
  # runner does next. 404 is the daemon saying the image is not on the node,
  # which is the only refusal that says anything about the image at all: the
  # image is checked before the name, so every other code is reached having
  # already found it.
  class DaemonRefused < RuntimeError
    def initialize(code, message)
      @code = code
      super(message)
    end

    attr_reader :code

    NO_SUCH_IMAGE = 404
  end

  def initialize(docker)
    @docker = docker
  end

  def run(id, image_name, container_name, max_seconds, tgz_in)
    container_id = create(image_name, container_name)
    # Everything past the create owns a container, and so has to dispose of it
    # however it ends. A refused create is outside, having made none to stop.
    begin
      docker.start_container(container_id)
      exec_cyber_dojo_sh(container_id, id, max_seconds, tgz_in)
    ensure
      stop(container_id)
    end
  end

  private

  attr_reader :docker

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
  # for the rest of that sleep. One second is enough for cyber-dojo.sh's own
  # EXIT trap to get its chance before the SIGKILL, and AutoRemove then
  # disposes of the container.
  def stop(container_id)
    docker.stop_container(container_id, seconds: 1)
  end

  # The container depends on its image alone, so nothing about this run is
  # said here. Its command sleeps, which is what keeps it there to be exec'd.
  def create(image_name, container_name)
    config = CyberDojoShContainerConfig.image_config(image_name)
    code, body = docker.create_container(config, name: container_name)
    raise DaemonRefused.new(code, "create answered #{code}: #{body}") unless code.between?(200, 299)

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
