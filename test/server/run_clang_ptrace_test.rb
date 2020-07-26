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
      set_context(
        logger:StdoutLoggerSpy.new,
        piper:piper=PiperStub.new(stdout_tgz),
        process:process=ProcessSpawnerStub.new
      )
      puller.add(image_name)
      command = nil
      process.spawn { |cmd| command = cmd }
      process.detach { ThreadStub.new(42) }
      process.kill {}

      run_cyber_dojo_sh

      assert command.include?('--cap-add=SYS_PTRACE'), command
    end

  end
end
