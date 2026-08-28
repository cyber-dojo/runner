require_relative '../test_base'

class RunDaemonRefusedTest < TestBase

  test 'd4Hb10', %w(
  | outcome is faulty when the daemon refuses to create the container
  | rather than the refusal escaping as a 500
  | because the learner is owed a traffic light either way
  ) do
    set_context(
      logger: @logger = StdoutLoggerSpy.new,
      docker: DockerDaemonStub.new(
        create_code: 409,
        create_body: '{"message":"Conflict. The container name is already in use"}'
      )
    )
    images.add(image_name)

    run = run_cyber_dojo_sh

    assert_equal 'faulty', run['outcome']
    assert_equal Runner::STATUS[:faulty].to_s, run['status']
    assert_includes @logger.logged, 'already in use'
  end

  test 'd4Hb11', %w[
  | a create refused with 409 leaves the pulled set alone
  | because the daemon checks the image before the name,
  | so reaching a name conflict proves the image is on the node
  ] do
    set_context(
      logger: @logger = StdoutLoggerSpy.new,
      docker: DockerDaemonStub.new(
        create_code: 409,
        create_body: '{"message":"Conflict. The container name is already in use"}'
      )
    )
    images.add(image_name)

    run_cyber_dojo_sh

    assert_equal [image_name], images.names
  end
end
