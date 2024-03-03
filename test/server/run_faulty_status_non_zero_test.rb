require_relative '../test_base'

class RunFaultyGzipErrorTest < TestBase
  def self.id58_prefix
    'c7C'
  end

  # - - - - - - - - - - - - - - - - -

  test 'd55', %w[outcome is faulty when status is non zero] do
    stub_non_zero_status

    run_cyber_dojo_sh

    assert faulty?, run_result
    lines = @logger.logged.lines
    assert_equal 1, lines.size
    assert_json_line(lines[0], {
                       id: id58,
                       image_name: image_name,
                       message: 'faulty',
                       result: ''
                     })
  end

  private

  def stub_non_zero_status
    stdout_tgz = TGZ.of({ 'stderr' => 'any' })
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
      ThreadValueStub.new(status = 42)
    end
    process.kill { |signal, pid| tp.kill(signal, pid) }
  end
end
