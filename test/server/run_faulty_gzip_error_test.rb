require_relative '../test_base'

class RunFaultyGzipErrorTest < TestBase

  test 'c7Dd54', %w[outcome is faulty when the container's stdout is not a gzip stream] do
    stub_gzip_error

    run_cyber_dojo_sh

    assert faulty?, run_result
    assert_equal '144', status, run_result
    lines = @logger.logged.lines
    assert_equal 1, lines.size
    assert_json_line(lines[0], {
                       id: id58,
                       image_name: image_name,
                       error: 'Zlib::GzipFile::Error'
                     })
  end

  private

  def stub_gzip_error
    set_context(
      logger: @logger = StdoutLoggerSpy.new,
      docker: DockerDaemonStub.new(stdout: 'not-a-tgz')
    )
    puller.add(image_name)
  end
end
