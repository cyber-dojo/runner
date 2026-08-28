require_relative '../test_base'

class RunMissingContainerKeepsPulledTest < TestBase

  test 'K3nW8p', %w(
  | when the daemon answers 404 to an exec create it is the container that
  | has gone, not the image, so puller's pulled set is left alone
  | and a present image is not pulled all over again for nothing
  | see run_missing_image_invalidates_pulled_test.rb for the create that
  | does mean the image has gone
  ) do
    set_context(
      logger: @logger = StdoutLoggerSpy.new,
      docker: DockerDaemonStub.new(
        exec_code: 404,
        exec_body: '{"message":"No such container: c0ffee"}'
      )
    )
    puller.add(image_name)
    assert_equal [image_name], puller.image_names

    run_cyber_dojo_sh

    assert_equal [image_name], puller.image_names
    assert_includes @logger.logged, 'No such container: c0ffee'
  end
end
