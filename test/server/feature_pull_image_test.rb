# frozen_string_literal: true
require_relative 'test_base'

class FeaturePullImageTest < TestBase

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
  given gcc_assert has already been pulled,
  when I call pull_image(id,gcc_assert),
  then a new thread is not started, no shell command is run, and the result is :pulled
  ) do
    puller.add(gcc_assert)
    assert_equal :pulled, puller.pull_image(id:id, image_name:gcc_assert)
    refute @context.threader.called
  end

  # - - - - - - - - - - - - - - - - -

  test 't9M', %w(
  given gcc_assert has not already been pulled,
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
    expected = :pulling
    actual = puller.pull_image(id:id, image_name:gcc_assert)
    assert_equal expected, actual
    assert @context.threader.called
  end

  private

  def gcc_assert
    'cyberdojofoundation/gcc_assert:93eefc6'
  end

  def puller
    context.puller
  end

end