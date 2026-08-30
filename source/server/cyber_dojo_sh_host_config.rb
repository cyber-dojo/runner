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

  # The memory ceiling a kata runs under.
  MEMORY_BYTES = 2 * GB

  # How many processes a kata may have, which is what stops a fork bomb.
  MAX_PROCESSES = 128

  # What a kata cannot do: reach the network, exhaust the node's memory, fork
  # bomb it, or gain a privilege it did not start with. The two ceilings are
  # named rather than written here, because CyberDojoShOciConfig expresses the
  # same two and a second copy of a number is a number that can drift.
  def self.limits
    {
      'Memory' => MEMORY_BYTES,
      'NetworkMode' => 'none',
      'PidsLimit' => MAX_PROCESSES,
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
  # Each tmpfs a kata writes into, and the options it is mounted with. Named,
  # and kept as the options one by one, because CyberDojoShOciConfig mounts the
  # same two and an OCI runtime takes the options as a list where the docker
  # rendering takes them as one joined string.
  def self.tmpfs_options
    {
      Sandbox::DIR => ['exec', 'size=250M', "uid=#{Sandbox::UID}", "gid=#{Sandbox::GID}"],
      '/tmp' => ['exec', 'size=250M', 'mode=1777']
    }
  end

  def self.tmp_file_systems
    { 'Tmpfs' => tmpfs_options.transform_values { |options| options.join(',') } }
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

  # The limits one image's kata runs under. A clang image loses the data limit
  # for the reason ptrace below is added. Named because CyberDojoShOciConfig
  # gives the same limits under names of its own, and a second copy of this
  # choice is a choice that can drift.
  def self.resource_limits(image_name)
    clang?(image_name) ? LIMIT_OF.except('data') : LIMIT_OF
  end

  def self.ulimits(image_name)
    { 'Ulimits' => resource_limits(image_name).map { |name, limit| ulimit(name, limit) } }
  end
  private_class_method :ulimits

  # clang and clang++ offer -fsanitize=address, whose sanitizer reserves a
  # large virtual address space that the data ulimit would refuse, and which
  # needs ptrace to report what it finds. So a clang image trades the one for
  # the other, and no other image is given the capability.
  # The capabilities this image is given beyond the set the daemon leaves every
  # container. Named because CyberDojoShOciConfig adds the same ones to a
  # bounding set it states in full.
  def self.added_capabilities(image_name)
    clang?(image_name) ? ['SYS_PTRACE'] : []
  end

  def self.ptrace(image_name)
    added = added_capabilities(image_name)
    added.empty? ? {} : { 'CapAdd' => added }
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
