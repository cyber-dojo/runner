require_relative '../test_base'

class RunFaultyTarErrorTest < TestBase

  test 'Bc4a9F', %w[outcome is faulty when the payload inflates to something that is not a tar] do
    stub_tar_error

    run_cyber_dojo_sh

    assert faulty?, run_result
    assert_equal '144', status, run_result
    assert_equal({}, created, run_result)
    lines = @logger.logged.lines
    assert_equal 1, lines.size
    assert_json_line(lines[0], {
                       id: id58,
                       image_name: image_name,
                       error: 'Gem::Package::TarInvalidError'
                     })
  end

  private

  # Gem::Package::TarHeader verifies neither the header checksum nor the ustar
  # magic, so bytes like these parse into entries with junk names. The names
  # and their contents would reach the browser as created files, which is what
  # TarFile::Reader's ustar check exists to stop.
  def stub_tar_error
    set_context(
      logger: @logger = StdoutLoggerSpy.new,
      docker: DockerDaemonStub.new(stdout: Gnu.zip('not-a-tar'))
    )
    images.add(image_name)
  end
end
