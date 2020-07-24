# frozen_string_literal: true
require_relative '../test_base'

module Server
  class NodeTest < TestBase

    def self.id58_prefix
      '3q1'
    end

    # - - - - - - - - - - - - - - - - - - - - -

    test 'Ps3', %w( image_names are retrieved from the node via docker image ls call ) do
      stub_sheller_capture
      sheller.capture(DOCKER_IMAGE_LS_COMMAND) { [expected.join("\n"),'',0] }
      actual = node.image_names
      assert_equal expected, actual
    end

    # - - - - - - - - - - - - - - - - - - - - -

    test 'Ps4', %w( <none>:<none> image_names are filtered out ) do
      stub_sheller_capture
      tainted = (expected + ['<none>:<none>']*3).shuffle
      sheller.capture(DOCKER_IMAGE_LS_COMMAND) { [tainted.join("\n"),'',0] }
      actual = node.image_names
      assert_equal expected, actual
    end

    # - - - - - - - - - - - - - - - - - - - - -

    test 'Ps5', %w( image_names populate puller in config.ru ) do
      stub_sheller_capture
      sheller.capture(DOCKER_IMAGE_LS_COMMAND) { [expected.join("\n"),'',0] }
      node.image_names.each do |image_name|
        puller.add(image_name)
      end
      assert_equal expected, puller.image_names
    end

    # - - - - - - - - - - - - - - - - - - - - -

    test 'Ps6', %w( when docker image ls call fails exception is raised ) do
      stub_sheller_capture
      sheller.capture(DOCKER_IMAGE_LS_COMMAND) { ['','stderr-info',1] }
      error = assert_raises { node.image_names }
      assert_equal 'stderr-info', error.message
    end

    private

    def stub_sheller_capture
      context.instance_exec { @sheller = BashShellerStub.new }
    end

    DOCKER_IMAGE_LS_COMMAND = "docker image ls --format '{{.Repository}}:{{.Tag}}'"

    def expected
      %w(
        cyberdojo/avatars:1fce37b
        cyberdojo/saver:723349e
        openjdk:13-jdk-alpine
        cyberdojo/versioner:latest
        cyberdojo/commander:b291513
        cyberdojo/web-base:63adedc
      ).sort
    end

    def node
      context.node
    end

    def sheller
      context.sheller
    end

  end
end
