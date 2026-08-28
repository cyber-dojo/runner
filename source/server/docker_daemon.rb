# Every endpoint the runner uses on the docker daemon, over a transport that
# speaks HTTP on a unix socket. This is the complete list, which is what
# docs/docker-socket-privilege.md needs to say what a socket proxy would have
# to allow.
#
# Answers [code,body] as the transport does. Which code means what differs by
# caller, so saying it here would take that decision away from them.
class DockerDaemon
  def initialize(context)
    @context = context
  end

  # Every image on the node, each carrying the RepoTags naming it.
  def image_names
    http.request('GET', '/images/json')
  end

  # Pulls image_name onto the node, blocking until the pull ends. The tag rides
  # inside fromImage, which the daemon parses as one reference, so nothing has
  # to split the name apart.
  def pull_image(image_name)
    http.request('POST', "/images/create?fromImage=#{image_name}")
  end

  # Creates a container from config. The name is a query parameter rather than
  # part of the body, which is the one thing the docker CLI's flags say that
  # the create config does not. A container nothing has to find again is
  # created without one.
  def create_container(config, name: nil)
    named = name.nil? ? '' : "?name=#{name}"
    http.request('POST', "/containers/create#{named}", config)
  end

  # Starts a created container.
  def start_container(id)
    http.request('POST', "/containers/#{id}/start")
  end

  # Makes an exec inside a container that is already running, from config, and
  # answers what the daemon said, the new exec's id being in the body. This is
  # how a run reaches a container created before the run was known: the config
  # carries the command and the vars belonging to that one run.
  def create_exec(container_id, config)
    http.request('POST', "/containers/#{container_id}/exec", config)
  end

  # Runs a created exec, answering its hijacked socket, which carries stdin one
  # way and both output streams the other, multiplexed, exactly as attaching to
  # a container does. Detach false is what keeps the streams on this
  # connection, and the tty is refused because a pty would corrupt the payload.
  def start_exec(exec_id)
    http.attach("/exec/#{exec_id}/start", { 'Detach' => false, 'Tty' => false })
  end

  # Stops a running container, giving it seconds to stop in: SIGTERM, and then
  # SIGKILL that many seconds later.
  def stop_container(id, seconds:)
    http.request('POST', "/containers/#{id}/stop?t=#{seconds}")
  end

  # Answers one file from inside the container, as a tar archive.
  def read_file(id, path)
    http.request('GET', "/containers/#{id}/archive?path=#{path}")
  end

  # Removes a container, which a container that never ran needs since nothing
  # else disposes of it.
  def remove_container(id)
    http.request('DELETE', "/containers/#{id}")
  end

  private

  def http
    @context.http
  end
end
