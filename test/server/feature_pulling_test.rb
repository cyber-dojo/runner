# frozen_string_literal: true
require_relative 'test_base'

class FeaturePullingTest < TestBase

  def self.id58_prefix
    'C5a'
  end

  def id58_setup
    @context = Context.new(
      logger:StdoutLoggerSpy.new,
      threader:SynchronousThreader.new,
      sheller:BashShellerStub.new
    )
  end

  # - - - - - - - - - - - - - - - - -

  test '25e', %w(
  when I call run_cyber_dojo_sh(),
  with an image_name that has not yet been pulled onto the node,
  then the docker pull runs in a new thread and the result is :pulling
  ) do
    @context.sheller.capture("docker pull #{image_name}") {
      stdout = [
        "Status: Downloaded newer image for #{image_name}",
        "docker.io/#{image_name}"
      ].join("\n")
      stderr = ''
      status = 0
      [stdout,stderr,status]
    }
    assert_equal [], puller.image_names
    run_cyber_dojo_sh
    assert pulling?, pretty_result(:outcome)
    assert @context.threader.called
    assert_equal [image_name], puller.image_names # because of SynchronousThreader
  end

end
