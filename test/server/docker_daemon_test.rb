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
  | create_container puts the name in a query parameter.
  | Every other flag the docker CLI takes is in the create config instead.
  ] do
    http = spied_http([201, created_body])
    config = CyberDojoShContainerConfig.image_config(image_name)

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
  | create_exec makes an exec inside a container that already exists
  | which is how a run reaches a container created before the run was known
  ] do
    http = spied_http([201, exec_created_body])
    config = CyberDojoShContainerConfig.exec_config(id58)

    assert_equal [201, exec_created_body], docker.create_exec(container_id, config)
    assert_equal [['POST', "/containers/#{container_id}/exec", config]], http.calls
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Tq9dM11', %w[
  | start_exec hijacks the connection the way attaching to a container does
  | but says in a body that it is not detaching and wants no tty
  | and answers the hijacked socket the transport handed back
  ] do
    http = spied_http([200, ''])

    assert_equal http.stream, docker.start_exec(exec_id)
    assert_equal "/exec/#{exec_id}/start", http.attached
    assert_equal({ 'Detach' => false, 'Tty' => false }, http.attached_body)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Tq9dM12', %w[
  | containers_named asks for the containers whose name holds the given one
  | the daemon matching by substring, which is what lets one spare prefix
  | count every worker's spares on the node without knowing how many workers
  | there are
  | and it asks for running containers only, so a spare whose sleep has ended
  | has left the count already
  ] do
    http = spied_http([200, containers_json])
    filters = '%7B%22name%22%3A%5B%22cyber_dojo_spare_%22%5D%7D'

    assert_equal [200, containers_json], docker.containers_named('cyber_dojo_spare_')
    assert_equal [['GET', "/containers/json?filters=#{filters}", nil]], http.calls
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'Tq9dM13', %w[
  | rename_container renames one, which is how claiming a spare takes it out
  | of the count of spares: a label cannot be changed after a create and a
  | name can
  ] do
    http = spied_http([204, ''])
    claimed = 'cyber_dojo_runner_K3nW8p_9a3b1c7d'

    assert_equal [204, ''], docker.rename_container(container_id, name: claimed)
    expected = "/containers/#{container_id}/rename?name=#{claimed}"
    assert_equal [['POST', expected, nil]], http.calls
  end

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

  # As POST /containers/{id}/exec answers it, naming the exec rather than the
  # container it was made in.
  def exec_id
    'b7c1e94d2a6f83051c9e7b4a2d8f60931e5c7a9b3d1f8264e0a7c5b93d2f81e64'
  end

  # As POST /containers/{id}/exec answers it, being the new exec's id alone.
  def exec_created_body
    "{\"Id\":\"#{exec_id}\"}"
  end

  # As GET /containers/json answers it: one running spare, carrying its name
  # with the leading slash the daemon gives it.
  def containers_json
    JSON.generate([
                    { 'Id' => container_id,
                      'Names' => ['/cyber_dojo_spare_w3_1a2b3c4d'],
                      'State' => 'running' }
                  ])
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
