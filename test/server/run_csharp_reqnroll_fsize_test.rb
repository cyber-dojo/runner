require_relative '../test_base'

class RunCSharpReqnRollFSizeTest < TestBase

  test 'Ea3d93', %w[
    csharp_reqnroll image requires very large ulimit file-size
  ] do
    stdout_tgz = TGZ.of({ 'stderr' => 'any' })
    set_context(
      logger: StdoutLoggerSpy.new,
      piper: piper = PipeMakerStub.new(stdout_tgz),
      process: process = ProcessSpawnerStub.new
    )
    image_name = "ghcr.io/cyber-dojo-languages/csharp_reqnroll:1234567"
    puller.add(image_name)
    command = nil
    process.spawn { |cmd| command = cmd }
    process.detach { ThreadValueStub.new(42) }
    process.kill {}

    run_cyber_dojo_sh({ :image_name => image_name })

    name = 'fsize'
    limit = 2048 * GB
    assert command.include?("--ulimit #{name}=#{limit}"), command
  end
end

KB = 1024
MB = 1024 * KB
GB = 1024 * MB
