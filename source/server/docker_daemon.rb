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

  # Creates a container from config. Everything the docker CLI would be told
  # in flags is in that config, except the name: the API takes it as a query
  # parameter instead. A container nothing has to find again is created
  # without one.
  def create_container(config, name: nil)
    named = name.nil? ? '' : "?name=#{name}"
    http.request('POST', "/containers/create#{named}", config)
  end

  # Answers the container's hijacked socket, which carries its stdin one way
  # and both its output streams the other, multiplexed.
  def attach_container(id)
    http.attach("/containers/#{id}/attach?stream=1&stdin=1&stdout=1&stderr=1")
  end

  # Starts a created container.
  def start_container(id)
    http.request('POST', "/containers/#{id}/start")
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
