require_relative '../test_base'
require_code 'externals/docker_socket'

class NodeTest < TestBase

  test '3q1Ps3', %w[image_names are the RepoTags the daemon answers,
                    one image being able to carry several of them] do
    set_context(docker: DockerDaemonSpy.new([[200, JSON.generate(daemon_images)]]))
    actual = node.image_names
    assert_equal expected, actual
    assert_equal [[:image_names]], docker.calls
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3q1Ps4', %w[an image with no RepoTags names nothing a manifest could
                    hold, and contributes no image_name] do
    dangling = [
      { 'Id' => 'sha256:34a35c5c04b4a0e5cfdd853a8477192634f5a1a5a54b6a80b3b33edd1e7fcdcb',
        'RepoTags' => [] },
      { 'Id' => 'sha256:34692745a2bfde5d67ba19550b5a3aed1110ec5aabb4cdc2cf72541d5e516e33',
        'RepoTags' => [] }
    ]
    tainted = (daemon_images + dangling).shuffle
    set_context(docker: DockerDaemonSpy.new([[200, JSON.generate(tainted)]]))
    actual = node.image_names
    assert_equal expected, actual
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3q1Ps5', %w[image_names populate the node's images in config.ru] do
    set_context(docker: DockerDaemonSpy.new([[200, JSON.generate(daemon_images)]]))
    node.image_names.each do |image_name|
      images.add(image_name)
    end
    assert_equal expected, images.names
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3q1Ps6', %w[when the daemon does not answer 200 an exception is raised
                    carrying what it said instead] do
    message = '{"message":"client version 1.22 is too old"}'
    set_context(docker: DockerDaemonSpy.new([[400, message]]))
    error = assert_raises { node.image_names }
    assert_equal message, error.message
  end

  test '3q1Ps8', %w[a real GET /images/json against the real daemon,
                    which is the only thing that says the socket request,
                    its headers and its chunked body carry a name the
                    daemon really holds, none of which a stub can judge] do
    set_context(http: client = DockerSocket.new)
    tagged = "#{owned_repo}:v1"

    refute_includes node.image_names, tagged

    code, body = client.request('POST', "/images/alpine:3.24/tag?repo=#{owned_repo}&tag=v1")
    assert_equal 201, code, body

    assert_includes node.image_names, tagged
  ensure
    # The tag is this test's own, so removing it takes nothing else with it.
    # alpine:3.24 keeps the image alive for the tests that pulled it.
    client.request('DELETE', "/images/#{tagged}")
  end

  private

  # Lowercase because a repository name may not carry capitals, and per-test
  # so that a name this test asserts the absence of cannot be one another
  # test, or another run, put there.
  def owned_repo
    "cyber-dojo-node-test-#{id58.downcase}"
  end

  # As GET /images/json answers them, out of alphabetical order, and with
  # fields alongside RepoTags that say nothing about what an image is named.
  def daemon_images
    [
      { 'Id' => 'sha256:8fabf019a49303ba48925e4769944d3d27f02fee2b581c09537fa82f9f758951',
        'RepoTags' => ['cyberdojo/runner:83c2554', 'cyberdojo/runner:latest'] },
      { 'Id' => 'sha256:0ce768d6bf6ca3e2bd001cb7a014df7cfb92bed461e7da6bb5bb9637fd92ffc5',
        'RepoTags' => ['openjdk:13-jdk-alpine'] },
      { 'Id' => 'sha256:30e6b0d669915981e3fa85a7debbc2d81bf23a2289f3d772ac8d642e2fc5b3aa',
        'RepoTags' => ['cyberdojo/saver:723349e'] },
      { 'Id' => 'sha256:1fce37b0a7ba4b9e5c0d8e1f2a3b4c5d6e7f8091a2b3c4d5e6f708192a3b4c5d',
        'RepoTags' => ['registry.example.com:5000/gcc_assert:2f1a3c9'] }
    ]
  end

  def expected
    %w[
      cyberdojo/runner:83c2554
      cyberdojo/runner:latest
      cyberdojo/saver:723349e
      openjdk:13-jdk-alpine
      registry.example.com:5000/gcc_assert:2f1a3c9
    ].sort
  end
end
