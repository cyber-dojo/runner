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
    stdout_tgz = Gnu.zip('not-a-tar')
    stderr = ''
    set_context(
      logger: @logger = StdoutLoggerSpy.new,
      process: process = ProcessSpawnerStub.new,
      threader: StdoutStderrReaderThreaderStub.new(stdout_tgz, stderr)
    )
    puller.add(image_name)
    tp = ProcessSpawner.new
    process.spawn { |_cmd, opts| tp.spawn('sleep 10', opts) }
    process.detach do |pid|
      tp.detach(pid)
      ThreadValueStub.new(0)
    end
    process.kill { |signal, pid| tp.kill(signal, pid) }
  end
end
