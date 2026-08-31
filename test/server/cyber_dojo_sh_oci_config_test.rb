require_relative '../test_base'
require_code 'cyber_dojo_sh_container_config'
require_code 'cyber_dojo_sh_oci_config'

class CyberDojoShOciConfigTest < TestBase

  test 'k7Rm10', %w(
  | the OCI config caps memory and processes where the docker create body caps them
  | so a container started from either is held to one set of limits
  ) do
    assert_equal host_config['Memory'], oci_config['linux']['resources']['memory']['limit']
    assert_equal host_config['PidsLimit'], oci_config['linux']['resources']['pids']['limit']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm11', %w(
  | the OCI config runs the container as the user the docker create body runs it as
  | so the two renderings cannot disagree about who a kata is
  ) do
    uid, gid = docker_config['User'].split(':').map { |part| Integer(part) }

    assert_equal uid, oci_config['process']['user']['uid']
    assert_equal gid, oci_config['process']['user']['gid']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm12', %w(
  | the OCI config runs the command the docker create body runs
  ) do
    assert_equal docker_config['Cmd'], oci_config['process']['args']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm13', %w(
  | the OCI config forbids gaining a privilege the container did not start with
  | which the docker create body asks for as a security option
  ) do
    assert_includes host_config['SecurityOpt'], 'no-new-privileges'
    assert oci_config['process']['noNewPrivileges'], 'noNewPrivileges'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm14', %w(
  | the OCI config gives the rlimits the docker create body gives
  | each named as an OCI runtime names it, and capped at the same value
  ) do
    expected = host_config['Ulimits'].map do |ulimit|
      {
        'type' => "RLIMIT_#{ulimit['Name'].upcase}",
        'soft' => ulimit['Soft'],
        'hard' => ulimit['Hard']
      }
    end

    assert_equal expected, oci_config['linux']['rlimits']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  clang_assert_test 'k7Rm15', %w(
  | a clang image loses the data rlimit in the OCI config, as it does in the
  | docker create body, because the sanitizer reserves a large virtual address
  | space that the limit would refuse
  ) do
    types = oci_config['linux']['rlimits'].map { |rlimit| rlimit['type'] }

    assert_equal host_config['Ulimits'].map { |ulimit| "RLIMIT_#{ulimit['Name'].upcase}" }, types
    refute_includes types, 'RLIMIT_DATA'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm23', %w(
  | the OCI config makes read only the five proc paths dockerd makes read only
  | as a test-run container's own mountinfo shows them bind mounted read only
  ) do
    assert_equal %w[
      /proc/bus /proc/fs /proc/irq /proc/sys /proc/sysrq-trigger
    ], oci_config['linux']['readonlyPaths']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm24', %w(
  | the OCI config masks the twelve paths dockerd masks whatever the node
  | as moby's daemon/pkg/oci/defaults.go lists them
  ) do
    assert_equal %w[
      /proc/acpi
      /proc/asound
      /proc/interrupts
      /proc/kcore
      /proc/keys
      /proc/latency_stats
      /proc/sched_debug
      /proc/scsi
      /proc/timer_list
      /proc/timer_stats
      /sys/devices/virtual/powercap
      /sys/firmware
    ], oci_config['linux']['maskedPaths']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm25', %w(
  | the OCI config mounts proc where dockerd mounts it
  | as docs/profiling/check_crun_run_from_oci_config.rb found a bundle without it
  | has no /proc/self/status to read
  ) do
    proc_mount = oci_config['mounts'].find { |mount| mount['destination'] == '/proc' }

    assert_equal 'proc', proc_mount['type']
    assert_equal 'proc', proc_mount['source']
    assert_equal %w[nosuid noexec nodev], proc_mount['options']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm26', %w(
  | the OCI config hands the container the image's env before the runner's own
  | which dockerd merges for a container and an OCI runtime does not
  ) do
    assert_equal image_config['Env'] + docker_config['Env'], oci_config['process']['env']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm27', %w(
  | the OCI config starts the process in the directory the image declares
  | which is where dockerd starts a container
  ) do
    assert_equal image_config['WorkingDir'], oci_config['process']['cwd']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm28', %w(
  | the OCI config starts the process at the root when the image declares no directory
  | which an OCI runtime needs because it takes no relative path
  ) do
    config = CyberDojoShOciConfig.config(id58, image_name, { 'Env' => [], 'WorkingDir' => '' })

    assert_equal '/', config['process']['cwd']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm19', %w(
  | the OCI config bounds a kata by the capabilities dockerd bounds it by
  | and gives it none of them, which is what dockerd gives it
  | as docs/profiling/check_test_run_confinement.rb measured
  ) do
    capabilities = oci_config['process']['capabilities']

    assert_equal %w[
      CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER CAP_FSETID CAP_KILL CAP_SETGID
      CAP_SETUID CAP_SETPCAP CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_CHROOT
      CAP_MKNOD CAP_AUDIT_WRITE CAP_SETFCAP
    ], capabilities['bounding']
    assert_equal [], capabilities['effective']
    assert_equal [], capabilities['permitted']
    assert_equal [], capabilities['inheritable']
    assert_equal [], capabilities['ambient']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm17', %w(
  | the OCI config mounts the two tmpfs the docker create body mounts
  | each with the options the docker rendering joins into one string
  ) do
    expected = host_config['Tmpfs'].map do |path, options|
      {
        'destination' => path,
        'type' => 'tmpfs',
        'source' => 'tmpfs',
        'options' => options.split(',')
      }
    end

    tmpfs_mounts = oci_config['mounts'].select { |mount| mount['type'] == 'tmpfs' }

    assert_equal expected, tmpfs_mounts
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm18', %w(
  | the OCI config makes the six namespaces dockerd makes for a container
  | each carrying no path, which is what makes it a new one
  | and asks for no user namespace, which dockerd shares rather than makes
  | as docs/profiling/check_test_run_confinement.rb measured
  ) do
    namespaces = oci_config['linux']['namespaces']

    assert_equal 'none', host_config['NetworkMode']
    assert_equal [
      { 'type' => 'cgroup' },
      { 'type' => 'ipc' },
      { 'type' => 'mount' },
      { 'type' => 'network' },
      { 'type' => 'pid' },
      { 'type' => 'uts' }
    ], namespaces
    refute_includes namespaces.map { |namespace| namespace['type'] }, 'user'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  clang_assert_test 'k7Rm20', %w(
  | a clang image is bounded by ptrace as well, which the docker create body
  | adds as a capability, and is still given no capability to use
  ) do
    capabilities = oci_config['process']['capabilities']

    assert_equal ['SYS_PTRACE'], host_config['CapAdd']
    assert_includes capabilities['bounding'], 'CAP_SYS_PTRACE'
    assert_equal [], capabilities['effective']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'k7Rm21', %w(
  | the OCI config carries the seccomp profile dockerd applies
  | refusing by default, and naming the architecture it was resolved for
  | and allowing a syscall a kata makes on every run
  ) do
    seccomp = oci_config['linux']['seccomp']

    assert_equal 'SCMP_ACT_ERRNO', seccomp['defaultAction']
    assert_equal %w[SCMP_ARCH_X86_64 SCMP_ARCH_X86 SCMP_ARCH_X32], seccomp['architectures']
    assert_includes seccomp['syscalls'].first['names'], 'execve'
    assert_equal 'SCMP_ACT_ALLOW', seccomp['syscalls'].first['action']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  clang_assert_test 'k7Rm22', %w(
  | a clang image is allowed the syscalls its extra capability unlocks
  | which the profile for every other image refuses
  ) do
    names = oci_config['linux']['seccomp']['syscalls'].flat_map { |syscall| syscall['names'] }

    assert_includes names, 'kcmp'
    assert_includes names, 'pidfd_getfd'
    assert_includes names, 'process_madvise'
  end

  private

  # What the language image's own config carries, which is what the image plane
  # answers. This is the perl image's, read off the daemon by
  # docs/profiling/check_crun_run_from_oci_config.rb
  def image_config
    {
      'Env' => ['PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'],
      'WorkingDir' => '/usr/src/app'
    }
  end

  def oci_config
    CyberDojoShOciConfig.config(id58, image_name, image_config)
  end

  def docker_config
    CyberDojoShContainerConfig.create_config(id58, image_name)
  end

  def host_config
    docker_config['HostConfig']
  end
end
