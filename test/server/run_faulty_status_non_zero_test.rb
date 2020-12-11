# frozen_string_literal: true
require_relative '../test_base'

class RunFaultyGzipErrorTest < TestBase

  def self.id58_prefix
    'c7C'
  end

  # - - - - - - - - - - - - - - - - -

  test 'd55', %w( outcome is faulty when status is non zero ) do
    stub_non_zero_status
    run_cyber_dojo_sh
    assert faulty?, run_result
  end

  private

  def stub_non_zero_status
    stdout_tgz = TGZ.of({'stderr' => 'any'})
    stderr = ''
    set_context(
        logger:StdoutLoggerSpy.new,
       process:process=ProcessSpawnerStub.new,
      threader:StdoutStderrReaderThreaderStub.new(stdout_tgz, stderr)
    )
    puller.add(image_name)
    tp = ProcessSpawner.new
    process.spawn { |_cmd,opts| tp.spawn('sleep 10', opts) }
    process.detach { |pid| tp.detach(pid); ThreadValueStub.new(status=42) }
    process.kill { |signal,pid| tp.kill(signal, pid) }
  end

end
