# frozen_string_literal: true
require_relative '../test_base'

module Dual
  class RunFaultyStatusNonZeroTest < TestBase

    def self.id58_prefix
      'c7D'
    end

    # - - - - - - - - - - - - - - - - -

    test 'd54', %w( outcome is faulty when gzip error ) do
      stub_gzip_error
      run_cyber_dojo_sh
      assert faulty?, run_result
    end

    private

    def stub_gzip_error
      stdout_tgz = 'not-a-tgz'
      stderr = ''
      @context = Context.new(
        logger:StdoutLoggerSpy.new,
        process:process=ProcessAdapterStub.new,
        threader:ThreaderStub.new(stdout_tgz, stderr)
      )
      puller.add(image_name)
      tp = ProcessAdapter.new
      process.spawn { |_cmd,opts| tp.spawn('sleep 10', opts) }
      process.detach { |pid| tp.detach(pid); ThreadStub.new(0) }
      process.kill { |signal,pid| tp.kill(signal, pid) }
    end

  end
end
