# frozen_string_literal: true
require_relative '../test_base'

class PullImageTest < TestBase
  def self.id58_prefix
    '9j5'
  end

  # - - - - - - - - - - - - - - - - -

  test 't9K', %w(
    given gcc_assert HAS already been pulled,
    when I call pull_image(id,gcc_assert),
    then a new thread is not started
    no shell command is run,
    nothing is logged,
    and the result is :pulled
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new
    )
    assert_equal [], puller.image_names
    puller.add(gcc_assert)
    expected = :pulled
    actual = puller.pull_image(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    assert_equal [gcc_assert], puller.image_names
    refute context.threader.called
    assert_equal context.logger.logged, ''
  end

  # - - - - - - - - - - - - - - - - -

  test 't9M', %w(
    given gcc_assert has NOT already been pulled,
    when I call pull_image(id, gcc_assert),
    then the docker-pull runs in a new thread
    and a message is logged
    and the result is :pulling
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      sheller: BashShellerStub.new
    )
    context.sheller.capture("docker pull #{gcc_assert}") do
      stdout = [
        "Status: Downloaded newer image for #{gcc_assert}",
        "docker.io/#{gcc_assert}"
      ].join("\n")
      stderr = ''
      status = 0
      [stdout, stderr, status]
    end
    assert_equal [], puller.image_names
    expected = :pulling
    actual = puller.pull_image(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    assert context.threader.called
    assert_equal [gcc_assert], puller.image_names
    assert_equal context.logger.logged, "Pulled docker image #{gcc_assert} (0.0 secs)\n"
  end

  # - - - - - - - - - - - - - - - - -

  test 't9N', %w(
    given gcc_assert has NOT already been pulled,
    when I call pull_image(id, gcc_assert),
    then the docker-pull runs in a new thread
    and if the docker-pull fails a message is logged
    and gcc_assert is not pulled
    and the result is :pulling
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      sheller: BashShellerStub.new
    )
    stdout = [
      "Some message",
      "docker.io/#{gcc_assert}"
    ].join("\n")
    stderr = 'A diagnostic'
    status = 4
    context.sheller.capture("docker pull #{gcc_assert}") do
      [stdout, stderr, status]
    end
    assert_equal [], puller.image_names
    expected = :pulling
    actual = puller.pull_image(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    assert context.threader.called
    assert_equal [], puller.image_names

    log_message = "Failed to pull docker image #{gcc_assert}, stdout=#{stdout}, stderr=#{stderr}\n"
    assert_equal context.logger.logged, log_message
  end

  # - - - - - - - - - - - - - - - - -

  test 't9P', %w(
    given gcc_assert has NOT already been pulled,
    but is currently being pulled,
    when I call pull_image(id, gcc_assert),
    then the docker-pull does NOT run 
    nothing is logged
    and the result is :pulling
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      sheller: BashShellerStub.new
    )

    puller.instance_variable_get(:@pulling).add(gcc_assert)
    assert_equal [], puller.image_names
    expected = :pulling
    actual = puller.pull_image(id: id, image_name: gcc_assert)
    assert_equal expected, actual
    refute context.threader.called
    assert_equal [], puller.image_names
    assert_equal context.logger.logged, ''
  end

  private

  def gcc_assert
    'cyberdojofoundation/gcc_assert:93eefc6'
  end
end
