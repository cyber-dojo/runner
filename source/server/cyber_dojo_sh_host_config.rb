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
  #     There is no cpu ulimit.
  # [2] fsize bounds every file the process writes, anywhere in the container,
  #     and not only the sandbox, so the sizes
  #     docs/profiling/measure_sandbox_high_water_marks.rb reports are a floor
  #     on what this has to allow rather than a measure of it. The largest file
  #     it saw in any of the 82 sandboxes was 3.4MB.
  #
  #     One thing needed more, and it was not a file. The BEAM JIT keeps its
  #     generated code in a 64MiB memfd mapped twice, once writable and once
  #     executable, and the kernel refuses a truncate that grows an inode past
  #     RLIMIT_FSIZE however the inode is backed. So this limit killed every
  #     BEAM start with SIGXFSZ while no sandbox held more than 16KB. The elixir
  #     and erlang start-points now pass +JMsingle true, which asks the JIT for
  #     one mapping that is both and creates no memfd, so they live inside this
  #     limit and give up write-execute separation inside the BEAM to do it.
  #
  #     A BEAM image without that flag needs exactly 64MiB, measured to the
  #     kilobyte: 65535KB kills it and 65536KB does not. Nothing else in the 82
  #     asks for more than 3.4MB.
  #
  #     Erlang's failure is the shape to remember. make reported the killed erlc
  #     as its own exit 2, which is what an ordinary red light looks like, so a
  #     survey of exit statuses found elixir, which answers 153 directly, and
  #     missed erlang entirely.
  #
  #     For an LTF that needs more and cannot be changed,
  #     docs/pre-started-container-pool.md carries a manifest limits override
  #     that raises a limit up to a ceiling this file owns.
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
