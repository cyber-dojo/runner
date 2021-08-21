require_relative '../test_base'

class RunClangPtraceTest < TestBase

  def self.id58_prefix
    's8E'
  end

  # - - - - - - - - - - - - - - - - -

  clang_assert_test 'k8W', %w(
  clang image requires docker run command with ptrace capability
  ) do
    stdout_tgz = TGZ.of({'stderr' => 'any'})
    set_context(
        logger:StdoutLoggerSpy.new,
        piper:piper=PipeMakerStub.new(stdout_tgz),
      process:process=ProcessSpawnerStub.new
    )
    puller.add(image_name)
    command = nil
    process.spawn { |cmd| command = cmd }
    process.detach { ThreadValueStub.new(42) }
    process.kill {}

    run_cyber_dojo_sh

    assert command.include?('--cap-add=SYS_PTRACE'), command
  end

end
