# frozen_string_literal: true
require_relative '../test_base'

module Server
  class PullImageTest < TestBase

    def self.id58_prefix
      '9j5'
    end

    def id58_setup
      @context = Context.new(
        logger:StdoutLoggerSpy.new,
        threader:SynchronousThreader.new,
        sheller:BashShellerStub.new
      )
    end

    # - - - - - - - - - - - - - - - - -

    test 't9K', %w(
    given gcc_assert HAS already been pulled,
    when I call pull_image(id,gcc_assert),
    then a new thread is not started, no shell command is run, and the result is :pulled
    ) do
      assert_equal [], puller.image_names
      puller.add(gcc_assert)
      expected = :pulled
      actual = puller.pull_image(id:id, image_name:gcc_assert)
      assert_equal expected, actual
      assert_equal [gcc_assert], puller.image_names
      refute @context.threader.called
    end

    # - - - - - - - - - - - - - - - - -

    test 't9M', %w(
    given gcc_assert has NOT already been pulled,
    when I call pull_image(id, gcc_assert),
    then the docker pull runs in a new thread and the result is :pulling
    ) do
      @context.sheller.capture("docker pull #{gcc_assert}") {
        stdout = [
          "Status: Downloaded newer image for #{gcc_assert}",
          "docker.io/#{gcc_assert}"
        ].join("\n")
        stderr = ''
        status = 0
        [stdout,stderr,status]
      }
      assert_equal [], puller.image_names
      expected = :pulling
      actual = puller.pull_image(id:id, image_name:gcc_assert)
      assert_equal expected, actual
      assert @context.threader.called
      assert_equal [gcc_assert], puller.image_names # because of SynchronousThreader
    end

    private

    def gcc_assert
      'cyberdojofoundation/gcc_assert:93eefc6'
    end

  end
end
