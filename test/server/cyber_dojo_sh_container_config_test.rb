require_relative '../test_base'
require_code 'cyber_dojo_sh_container_config'

class CyberDojoShContainerConfigTest < TestBase

  test 'f2Cd13', %w(
  | the daemon removes the container itself once it exits
  | and tini reaps whatever the kata leaves behind
  | and the kata gets no network, capped memory, and no fork bombs
  | and can gain no privilege it did not start with
  ) do
    assert host_config['AutoRemove'], 'AutoRemove'
    assert host_config['Init'], 'Init'
    assert_equal 2 * 1024 * 1024 * 1024, host_config['Memory']
    assert_equal 'none', host_config['NetworkMode']
    assert_equal 128, host_config['PidsLimit']
    assert_equal ['no-new-privileges'], host_config['SecurityOpt']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'f2Cd14', %w(
  | the sandbox and tmp dirs are tmpfs, which a tmpfs mounts noexec by default
  | so exec is set to make the kata's own binaries and scripts runnable
  | and the sandbox belongs to the sandbox user
  | and tmp gets the sticky bit, as /tmp does everywhere
  ) do
    assert_equal({
                   Sandbox::DIR => "exec,size=250M,uid=#{Sandbox::UID},gid=#{Sandbox::GID}",
                   '/tmp' => 'exec,size=250M,mode=1777'
                 }, host_config['Tmpfs'])
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'f2Cd15', %w(
  | a kata cannot fill the disk, hold every file handle, or blow the stack
  | and writes no core file, since binaries are not tarred back out
  | and the nproc limit is per user across all containers, not per container
  ) do
    assert_equal [
      ulimit('core', 0),
      ulimit('data', 4 * 1024 * 1024 * 1024),
      ulimit('fsize', 256 * 1024 * 1024),
      ulimit('locks', 1024),
      ulimit('nofile', 1024),
      ulimit('nproc', 1024),
      ulimit('stack', 16 * 1024 * 1024)
    ], host_config['Ulimits']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  clang_assert_test 'f2Cd16', %w(
  | a clang image gets the ptrace capability, which -fsanitize=address needs
  | and loses the data ulimit, because the sanitizer reserves a large
  | virtual address space that the limit would refuse
  ) do
    assert_equal ['SYS_PTRACE'], host_config['CapAdd']
    refute_includes host_config['Ulimits'].map { |u| u['Name'] }, 'data'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'f2Cd17', %w(
  | an image that is not clang gains no capability at all
  | and keeps the data ulimit the sanitizer would have refused
  ) do
    assert_nil host_config['CapAdd']
    assert_includes host_config['Ulimits'].map { |u| u['Name'] }, 'data'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'f2Cd18', %w(
  | The create body is everything one test-run needs.
  | It names the image, and drops that image's entrypoint.
  | It runs as the sandbox user, never as root.
  | It carries the image_name, the sandbox dir, and this run's id.
  | Its command unpacks the incoming files and runs cyber-dojo.sh.
  | It holds stdin open, which is how the tgz arrives.
  | There is no tty, which would corrupt the payload.
  ) do
    config = CyberDojoShContainerConfig.create_config(id58, image_name)

    assert_equal image_name, config['Image']
    assert_equal [], config['Entrypoint']
    assert_equal "#{Sandbox::UID}:#{Sandbox::GID}", config['User']
    assert_equal [
      "CYBER_DOJO_IMAGE_NAME=#{image_name}",
      "CYBER_DOJO_SANDBOX=#{Sandbox::DIR}",
      "CYBER_DOJO_ID=#{id58}"
    ], config['Env']
    assert_equal ['bash', '-c', 'tar -C / -zxf - && bash ~/cyber_dojo_main.sh'], config['Cmd']
    assert config['OpenStdin'], 'OpenStdin'
    assert config['AttachStdin'], 'AttachStdin'
    refute config['Tty'], 'Tty'
    refute_nil config['HostConfig']
  end

  private

  # image_name comes from the manifest of whichever OS the test runs under, so
  # the clang test builds a clang config from the same call.
  def config
    CyberDojoShContainerConfig.create_config(id58, image_name)
  end

  def host_config
    config['HostConfig']
  end

  # The API takes each ulimit as an object, where the CLI takes --ulimit
  # name=limit and applies it to both the soft and the hard limit.
  def ulimit(name, limit)
    { 'Name' => name, 'Soft' => limit, 'Hard' => limit }
  end
end
