require_relative '../test_base'

class RunMissingContainerKeepsPulledTest < TestBase

  test 'K3nW8p', %w(
  | The daemon answers 404 to the start.
  | That is the container gone, not the image.
  | So the node's images are left alone.
  | A present image is not pulled all over again for nothing.
  | See run_missing_image_invalidates_pulled_test.rb for the create that does
  | mean the image has gone.
  ) do
    set_context(
      logger: @logger = StdoutLoggerSpy.new,
      docker: DockerDaemonStub.new(
        start_code: 404,
        start_body: '{"message":"No such container: c0ffee"}'
      )
    )
    images.add(image_name)
    assert_equal [image_name], images.names

    run_cyber_dojo_sh

    assert_equal [image_name], images.names
    assert_includes @logger.logged, 'No such container: c0ffee'
  end
end
