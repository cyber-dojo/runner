require_relative 'sandbox'

# The HostConfig of a POST /containers/create for one press, gathering what
# the daemon does around the container rather than inside it. Its entries
# arrive in groups, the same way CyberDojoShContainerConfig's do.
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
  def self.limits
    {
      'Memory' => 2 * GB,
      'NetworkMode' => 'none',
      'PidsLimit' => 128,
      'SecurityOpt' => ['no-new-privileges']
    }
  end
  private_class_method :limits

  # Both dirs are tmpfs, which should be faster than the container's own
  # writable layer. A tmpfs is mounted as a secure mountpoint by default,
  # which includes noexec, so exec is set to make a kata's own binaries and
  # scripts runnable. The size accommodates start-points needing large files,
  # eg C#'s "dotnet restore". The sandbox belongs to the sandbox user, and
  # /tmp gets the sticky bit it has everywhere else.
  def self.tmp_file_systems
    {
      'Tmpfs' => {
        Sandbox::DIR => "exec,size=250M,uid=#{Sandbox::UID},gid=#{Sandbox::GID}",
        '/tmp' => 'exec,size=250M,mode=1777'
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
  LIMIT_OF = {
    'core' => 0,            # [0]
    'data' => 4 * GB,       # data segment size
    'fsize' => 256 * MB,    # file size
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
