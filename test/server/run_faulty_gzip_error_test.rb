require_relative '../test_base'

class RunFaultyStatusNonZeroTest < TestBase

  def self.id58_prefix
    'c7D'
  end

  # - - - - - - - - - - - - - - - - -

  test 'd54', %w( outcome is faulty when gzip error ) do
    stub_gzip_error

    run_cyber_dojo_sh

    assert faulty?, run_result
    lines = @logger.logged.lines
    assert_equal 1, lines.size
    assert_json_line(lines[0], {
      id:id58,
      image_name:image_name,
      error:'Zlib::GzipFile::Error'
    })
  end

  private

  def stub_gzip_error
    stdout_tgz = 'not-a-tgz'
    stderr = ''
    set_context(
        logger:@logger=StdoutLoggerSpy.new,
       process:process=ProcessSpawnerStub.new,
      threader:StdoutStderrReaderThreaderStub.new(stdout_tgz, stderr)
    )
    puller.add(image_name)
    tp = ProcessSpawner.new
    process.spawn { |_cmd,opts| tp.spawn('sleep 10', opts) }
    process.detach { |pid| tp.detach(pid); ThreadValueStub.new(0) }
    process.kill { |signal,pid| tp.kill(signal, pid) }
  end

end
