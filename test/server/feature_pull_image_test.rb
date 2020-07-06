# frozen_string_literal: true
require_relative 'test_base'

class FeaturePullImageTest < TestBase

  def self.id58_prefix
    '9j5'
  end

  def id58_setup
    @context = Context.new(
      logger:StreamWriterSpy.new,
      threader:ThreaderFake.new,
      sheller:ShellerStub.new
    )
  end

  # - - - - - - - - - - - - - - - - -

  test 't9K', %w(
  pull an already added image_name does not start a new thread and returns :pulled
  ) do
    puller.add(gcc_assert)
    assert_equal :pulled, puller.pull_image(id:id, image_name:gcc_assert)
    refute @context.threader.called
  end

  # - - - - - - - - - - - - - - - - -

  test 't9M', %w(
  pull a new image_name pulls it in a new thread and returns :pulling
  ) do
    @context.sheller.stub_capture(
      "docker pull #{gcc_assert}",
      [
        "Status: Downloaded newer image for #{gcc_assert}",
        "docker.io/#{gcc_assert}"
      ].join("\n"),
      '',
      0
    )
    expected = :pulling
    actual = puller.pull_image(id:id, image_name:gcc_assert)
    assert_equal expected, actual
    assert @context.threader.called
  end

  # - - - - - - - - - - - - - - - - -

  private

  class ThreaderFake
    attr_reader :called
    def initialize
      @called = false
    end
    def thread(&block)
      @called = true
      block.call
    end
  end

  def gcc_assert
    'cyberdojofoundation/gcc_assert:93eefc6'
  end

  def puller
    context.puller
  end

end
