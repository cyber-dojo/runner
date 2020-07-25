# frozen_string_literal: true
require_relative '../test_base'

module Dual
  class RunFaultyStatusNonZeroTest < TestBase

    def self.id58_prefix
      'c7C'
    end

    # - - - - - - - - - - - - - - - - -

    csharp_nunit_test 'd55', %w( outcome is faulty when status is non zero ) do
      stub('any', status=42)
      run_cyber_dojo_sh
      assert faulty?, run_result
    end

    private

    def stub(mx_stderr, status)
      stdout_tgz = TGZ.of({'stderr' => mx_stderr})
      stderr = ''
      @context = Context.new(
        logger:StdoutLoggerSpy.new,
        process:process=ProcessAdapterStub.new,
        threader:ThreaderStub.new(stdout_tgz, stderr)
      )
      puller.add(image_name)
      tp = ProcessAdapter.new
      process.spawn { |_cmd,opts| tp.spawn('sleep 10', opts) }
      process.detach { |pid| tp.detach(pid); ThreadStub.new(status) }
      process.kill { |signal,pid| tp.kill(signal, pid) }
    end

  end
end
