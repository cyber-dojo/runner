require_relative 'sandbox'

# The HostConfig of a POST /containers/create for one run of cyber-dojo.sh,
# gathering what the daemon does around the container rather than inside it.
# Its entries arrive in groups, the same way CyberDojoShContainerConfig's do.
module CyberDojoShHostConfig
  def self.config(image_name)
    {
      'HostConfig' => [
        disposal,
        limits,
        tmp_file_systems,
        ulimits(image_name),
        ptrace(image_name)
      ].reduce(:merge)
    }
  end

  # The container is single-use. AutoRemove belongs to the container rather
  # than to the client, so the daemon removes it whatever becomes of whoever
  # asked for it. Init runs tini as PID 1, which reaps whatever a kata leaves
  # behind and makes removal much faster.
  def self.disposal
    {
      'AutoRemove' => true,
      'Init' => true
    }
  end
  private_class_method :disposal

  GB = 1024 * 1024 * 1024

  # What a kata cannot do: reach the network, exhaust the node's memory, fork
  # bomb it, or gain a privilege it did not start with.
  #
  # The memory limit is per container, so what it bounds on the node is itself
  # times however many test-runs are in flight. That is what makes it worth
  # being tight about: 768MB is about three times the most any of the seven
  # start-points in docs/profiling/measure_sandbox_high_water_marks.rb reached,
  # the worst being 260MB, and the tmpfs a kata writes into is charged to it.
  def self.limits
    {
      'Memory' => 768 * MB,
      'NetworkMode' => 'none',
      'PidsLimit' => 128,
      'SecurityOpt' => ['no-new-privileges']
    }
  end
  private_class_method :limits

  # Both dirs are tmpfs, which should be faster than the container's own
  # writable layer. A tmpfs is mounted as a secure mountpoint by default,
  # which includes noexec, so exec is set to make a kata's own binaries and
  # scripts runnable. The sandbox belongs to the sandbox user, and /tmp gets
  # the sticky bit it has everywhere else.
  #
  # The size is what a start-point's own kata needs, with room for a learner
  # who has written more.
  # docs/profiling/measure_sandbox_high_water_marks.rb ran all 82 of them: the
  # largest sandbox reached 20MB, Python with unittest-approval, and the
  # largest /tmp about 1.2MB. A tmpfs occupies only what is written to it, so
  # this bounds a runaway rather than reserving anything, and what bounds it in
  # turn is Memory, tmpfs pages being charged to the container's own cgroup.
  def self.tmp_file_systems
    {
      'Tmpfs' => {
        Sandbox::DIR => "exec,size=64M,uid=#{Sandbox::UID},gid=#{Sandbox::GID}",
        '/tmp' => 'exec,size=64M,mode=1777'
      }
    }
  end
  private_class_method :tmp_file_systems

  MB = 1024 * 1024

  # [0] No core file. Binaries are not tarred out of the container, so a core
  #     file would only fill the sandbox.
  # [1] The nproc limit is per user across all containers, not per container.
  #     See docs.docker.com/engine/reference/commandline/run/#set-ulimits-in-container---ulimit
  # [2] fsize bounds every file the process writes, anywhere in the container,
  #     and not only the sandbox. So the sizes
  #     docs/profiling/measure_sandbox_high_water_marks.rb reports are a floor
  #     on what this has to allow rather than a measure of it: the largest file
  #     it saw in any of the 82 sandboxes was 3.4MB, and this limit kills
  #     elixir_exunit's kata with SIGXFSZ, exit 153, its sandbox holding 16KB
  #     at the time. Whatever Erlang writes, it writes somewhere that probe
  #     cannot see. Changing the limit alone moves that kata between 2 and 153,
  #     which is how it was isolated from the tmpfs sizes.
  #
  #     So this is set for the common case, and the outliers are handled before
  #     prod: docs/pre-started-container-pool.md carries the manifest limits
  #     override, which lets an LTF raise what it needs up to a ceiling the
  #     runner owns. Until one of those is in place, a global cap of zero turns
  #     the whole thing off.
  #     There is no cpu ulimit.
  LIMIT_OF = {
    'core' => 0,            # [0]
    'data' => 4 * GB,       # data segment size
    'fsize' => 16 * MB,     # file size [2]
    'locks' => 1024,        # number of file locks
    'nofile' => 1024,       # number of files
    'nproc' => 1024,        # number of processes [1]
    'stack' => 16 * MB      # stack size
  }.freeze

  def self.ulimits(image_name)
    limits = clang?(image_name) ? LIMIT_OF.except('data') : LIMIT_OF
    { 'Ulimits' => limits.map { |name, limit| ulimit(name, limit) } }
  end
  private_class_method :ulimits

  # clang and clang++ offer -fsanitize=address, whose sanitizer reserves a
  # large virtual address space that the data ulimit would refuse, and which
  # needs ptrace to report what it finds. So a clang image trades the one for
  # the other, and no other image is given the capability.
  def self.ptrace(image_name)
    if clang?(image_name)
      { 'CapAdd' => ['SYS_PTRACE'] }
    else
      {}
    end
  end
  private_class_method :ptrace

  def self.clang?(image_name)
    image_name.start_with?('cyberdojofoundation/clang') ||
      image_name.start_with?('ghcr.io/cyber-dojo-languages/clang')
  end
  private_class_method :clang?

  # The API takes each ulimit as an object, where the CLI takes --ulimit
  # name=limit and applies the one limit to both the soft and the hard limit.
  def self.ulimit(name, limit)
    { 'Name' => name, 'Soft' => limit, 'Hard' => limit }
  end
  private_class_method :ulimit
end
