require_relative '../test_base'
require_code 'cyber_dojo_sh_container_config'
require_code 'docker_daemon'

class DockerDaemonTest < TestBase

  test 'Tq9dM1', %w[
  | image_names asks for every image the node holds
  | and answers what the daemon said, unparsed
  ] do
    http = spied_http([200, images_json])
    assert_equal [200, images_json], docker.image_names
    assert_equal [['GET', '/images/json', nil]], http.calls
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Tq9dM2', %w[
  | pull_image sends the tag inside fromImage
  | which the daemon parses as one reference
  ] do
    http = spied_http([200, pull_progress])
    assert_equal [200, pull_progress], docker.pull_image(image_name)
    assert_equal [['POST', "/images/create?fromImage=#{image_name}", nil]], http.calls
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Tq9dM3', %w[
  | create_container names no container when it is given no name
  | which is a container nothing has to find again
  ] do
    http = spied_http([201, created_body])
    config = { 'Image' => image_name }
    assert_equal [201, created_body], docker.create_container(config)
    assert_equal [['POST', '/containers/create', config]], http.calls
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Tq9dM4', %w[
  | create_container puts the name in a query parameter
  | which is the one thing the docker CLI's flags say
  | that the create config does not
  ] do
    http = spied_http([201, created_body])
    config = CyberDojoShContainerConfig.create_config(id58, image_name)

    assert_equal [201, created_body], docker.create_container(config, name: container_name)
    assert_equal [['POST', "/containers/create?name=#{container_name}", config]], http.calls
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Tq9dM6', %w[start_container starts the container the create answered] do
    http = spied_http([204, ''])
    assert_equal [204, ''], docker.start_container(container_id)
    assert_equal [['POST', "/containers/#{container_id}/start", nil]], http.calls
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Tq9dM7', %w[
  | stop_container says how long the container has to stop in
  | which is SIGTERM and then SIGKILL that many seconds later
  ] do
    http = spied_http([204, ''])
    assert_equal [204, ''], docker.stop_container(container_id, seconds: 1)
    assert_equal [['POST', "/containers/#{container_id}/stop?t=1", nil]], http.calls
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Tq9dM8', %w[
  | read_file answers one file out of the container as a tar archive
  ] do
    http = spied_http([200, tar_bytes])
    filename = '/usr/local/bin/red_amber_green.rb'
    assert_equal [200, tar_bytes], docker.read_file(container_id, filename)
    assert_equal [['GET', "/containers/#{container_id}/archive?path=#{filename}", nil]], http.calls
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Tq9dM9', %w[
  | remove_container removes a container that never ran
  | which nothing else disposes of
  ] do
    http = spied_http([204, ''])
    assert_equal [204, ''], docker.remove_container(container_id)
    assert_equal [['DELETE', "/containers/#{container_id}", nil]], http.calls
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Tq9dM10', %w[
  | attach_container hijacks the connection, and answers the socket the
  | transport handed back.
  | It asks for stdin, stdout and stderr, and for a stream rather than what
  | the container has already written.
  | A run attaches before it starts the container, so nothing the container
  | writes is missed.
  ] do
    http = spied_http([200, ''])

    assert_equal http.stream, docker.attach_container(container_id)
    expected = "/containers/#{container_id}/attach?stream=1&stdin=1&stdout=1&stderr=1"
    assert_equal expected, http.attached
  end

  # - - - - - - - - - - - - - - - - - - - - -

  private

  # Wires the daemon to a transport that answers response and remembers what it
  # was asked, which is where the docker URL becomes something a test can pin.
  def spied_http(response)
    http = DockerSocketSpy.new(response)
    set_context(http: http)
    http
  end

  # As runner.rb builds it, from the kata id and a per-run random hex8.
  def container_name
    "cyber_dojo_runner_#{id58}_9a3b1c7d"
  end

  # As POST /containers/create answers it, in full rather than truncated.
  def container_id
    '3f9a1c8b7d2e46a5b09c1d8e7f60a3b25c4d6e8f091a2b3c4d5e6f708192a3b4c'
  end

  # As POST /containers/create answers it, being the id and nothing warned of.
  def created_body
    "{\"Id\":\"#{container_id}\",\"Warnings\":[]}"
  end

  # As GET /images/json answers it, with fields alongside RepoTags.
  def images_json
    JSON.generate([
                    { 'Id' => 'sha256:8fabf019a49303ba48925e4769944d3d27f02fee2b581c09537fa82f9f758951',
                      'RepoTags' => ['cyberdojo/gcc_assert:2f1a3c9'] }
                  ])
  end

  # As POST /images/create streams it, newline-delimited, one object per layer.
  def pull_progress
    [
      '{"status":"Pulling from cyberdojo/gcc_assert","id":"2f1a3c9"}',
      '{"status":"Download complete","id":"a4e15e2b1a1c"}',
      ''
    ].join("\n")
  end

  # Stands in for the archive GET /containers/{id}/archive answers.
  def tar_bytes
    "red_amber_green.rb#{"\0" * 84}"
  end

  # Records what it was asked and answers one canned [code,body], standing in
  # for the transport so that a test can pin the docker URL built onto it.
  class DockerSocketSpy
    attr_reader :calls, :attached, :attached_body, :stream

    def initialize(response)
      @response = response
      @calls = []
      @stream = Object.new
    end

    def request(method, path, body = nil)
      @calls << [method, path, body]
      @response
    end

    def attach(path, body = nil)
      @attached = path
      @attached_body = body
      @stream
    end
  end
end
