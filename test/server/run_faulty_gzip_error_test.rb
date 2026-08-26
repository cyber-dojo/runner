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
    stdout_tgz = 'not-a-tgz'
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
  end
end
