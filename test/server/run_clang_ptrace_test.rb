# frozen_string_literal: true
require_relative '../test_base'

module Dual
  class RunClangPtraceTest < TestBase

    def self.id58_prefix
      's8E'
    end

    # - - - - - - - - - - - - - - - - -

    clang_assert_test 'k8W', %w( clang image adds ptrace capability ) do
      stdout_tgz = TGZ.of({'stderr' => 'any'})
      stderr = ''
      @context = Context.new(
        logger:StdoutLoggerSpy.new,
        process:process=ProcessSpawnerStub.new,
        threader:ThreaderStub.new(stdout_tgz, stderr)
      )
      puller.add(image_name)
      tp = ProcessSpawner.new
      command = nil
      process.spawn { |cmd,opts| command = cmd; tp.spawn('sleep 10', opts) }
      process.detach { |pid| tp.detach(pid); ThreadStub.new(0) }
      process.kill { |signal,pid| tp.kill(signal, pid) }

      run_cyber_dojo_sh

      assert command.include?('--cap-add=SYS_PTRACE'), command
    end

  end
end
