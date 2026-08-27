require 'json'
require_relative 'cyber_dojo_sh_container_config'
require_relative 'deadline_reader'
require_relative 'docker_attach_frames'

# Runs one cyber-dojo.sh in a container, talking to the docker daemon over its
# socket rather than spawning the docker CLI to do it. Answers what the
# container sent back, and whether it ran out of time.
#
# There is no exit status in the answer. The container is created with
# AutoRemove, so it is gone the moment it exits and there is nothing left to
# ask; and a payload that parses and holds tmp/status is itself proof the run
# was fine. A payload that does not parse is faulty however the container
# exited.
class DaemonRun
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

  def initialize(client)
    @client = client
  end

  def run(id, image_name, container_name, max_seconds, tgz_in)
    container_id = create(id, image_name, container_name)
    # Attaching before starting is what stops the container's first bytes
    # being written before anything is listening for them.
    stream = attach(container_id)
    start(container_id)
    send_tgz(stream, tgz_in)
    result_of(container_id, stream, max_seconds)
  end

  private

  attr_reader :client

  # The name is a query parameter rather than part of the body, which is the
  # one thing the CLI's flags say that the create config does not.
  def create(id, image_name, container_name)
    code, body = client.request(
      'POST',
      "/containers/create?name=#{container_name}",
      CyberDojoShContainerConfig.create_config(id, image_name)
    )
    raise DaemonRefused.new(code, "create answered #{code}: #{body}") unless code.between?(200, 299)

    JSON.parse(body)['Id']
  end

  def attach(container_id)
    client.attach("/containers/#{container_id}/attach?stream=1&stdin=1&stdout=1&stderr=1")
  end

  def start(container_id)
    client.request('POST', "/containers/#{container_id}/start")
  end

  # Shutting down the writing half is what gives the container's
  # [tar -zxf -] its end of file. Without it the container waits for one that
  # never comes, and so does whoever is reading its stdout. The reading half
  # stays open, because that is where the payload arrives.
  def send_tgz(stream, tgz_in)
    stream.write(tgz_in)
    stream.close_write
  end

  # What the container sent, or a stopped container and timed_out. Nothing
  # partial is answered: what arrived before the deadline passed is not a
  # whole payload.
  def result_of(container_id, stream, max_seconds)
    stdout, stderr = read_payload(stream, max_seconds)
    { timed_out: false, stdout: stdout, stderr: stderr }
  rescue DeadlineReader::Expired
    stop(container_id)
    { timed_out: true, stdout: '', stderr: '' }
  end

  STOP_SECONDS = 1

  # Stopping the container is what ends a timed-out run. --time 1 is SIGTERM
  # and then SIGKILL a second later, so cyber-dojo.sh's own EXIT trap still
  # gets its chance to run, and AutoRemove then disposes of the container.
  def stop(container_id)
    client.request('POST', "/containers/#{container_id}/stop?t=#{STOP_SECONDS}")
  end

  # The deadline starts once the container has everything it needs, and bounds
  # the whole read rather than each part of it.
  def read_payload(stream, max_seconds)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + max_seconds
    DockerAttachFrames.demultiplex(DeadlineReader.new(stream, deadline))
  end
end
