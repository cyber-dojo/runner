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
        [
          # Asked before the pull is started, because a miss is only what this
          # worker believes. The node does not hold it either.
          [404, %({"message":"No such image: #{image_name}"})],
          [200, %({"status":"Status: Downloaded newer image for #{image_name}"})]
        ]
      )
    )
    assert_equal [], images.names
    run_cyber_dojo_sh
    assert pulling?, pretty_result(:outcome)
    assert context.threader.called
    assert_equal [image_name], images.names # because of ThreaderSynchronous
  end

  # - - - - - - - - - - - - - - - - -

  test 'C5a25f', %w(
  | run_cyber_dojo_sh() takes a manifest image_name with no tag.
  | It is pulled as the :latest it means, and the result is :pulling.
  ) do
    untagged = 'cyberdojofoundation/gcc_assert'
    set_context(
      logger: StdoutLoggerSpy.new,
      threader: ThreaderSynchronous.new,
      docker: DockerDaemonSpy.new(
        [
          [404, %({"message":"No such image: #{untagged}:latest"})],
          [200, %({"status":"Status: Downloaded newer image for #{untagged}:latest"})]
        ]
      )
    )
    run_cyber_dojo_sh(image_name: untagged)
    assert pulling?, pretty_result(:outcome)
    assert_equal ["#{untagged}:latest"], images.names
  end
end
