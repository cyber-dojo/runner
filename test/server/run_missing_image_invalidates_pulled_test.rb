require_relative '../test_base'

class RunMissingImageInvalidatesPulledTest < TestBase

  test 'F7kR2m', %w(
  | when the daemon answers 404 to create, the image is not on the node,
  | so it is dropped from puller's pulled set
  | and the next test-run pulls it again rather than failing for ever
  ) do
    set_context(
      logger: @logger = StdoutLoggerSpy.new,
      docker: DockerDaemonStub.new(
        create_code: 404,
        create_body: %({"message":"No such image: #{image_name}"})
      )
    )
    puller.add(image_name)
    assert_equal [image_name], puller.image_names

    run_cyber_dojo_sh

    assert_equal [], puller.image_names
    assert_includes @logger.logged, "No such image: #{image_name}"
  end
end
