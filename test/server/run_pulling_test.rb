require_relative '../test_base'

class RunPullingTest < TestBase

  test 'C5a25e', %w(
  | when I call run_cyber_dojo_sh(),
  | with an image_name that has not yet been pulled onto the node,
  | then the docker pull runs in a new thread and the result is :pulling
  ) do
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      docker: DockerDaemonSpy.new(
        [[200, %({"status":"Status: Downloaded newer image for #{image_name}"})]]
      )
    )
    assert_equal [], images.names
    run_cyber_dojo_sh
    assert pulling?, pretty_result(:outcome)
    assert context.threader.called
    assert_equal [image_name], images.names # because of ThreaderSynchronous
  end
end
