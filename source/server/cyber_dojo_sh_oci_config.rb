require 'json'
require_relative 'cyber_dojo_sh_container_config'
require_relative 'cyber_dojo_sh_host_config'
require_relative 'sandbox'

# The OCI runtime config for one run of cyber-dojo.sh, saying what
# CyberDojoShContainerConfig says to the docker daemon, and saying as well the
# boundary dockerd applies without being asked.
#
# No test-run comes through here. dockerd is what runs a kata, and this is here
# so that the mapping onto an OCI runtime is written down and checked by a test
# before anything depends on it. See docs/dropping-the-docker-daemon.md
#
# Two kinds of thing are stated. The translations, which say in OCI terms what
# the two config classes say in docker terms: the user, the command, the env,
# no-new-privileges, the tmpfs, the memory and pids limits, the rlimits. And
# the defaults, which neither config class names because dockerd supplies them:
# process.capabilities, the namespaces, the seccomp profile, the masked and
# read-only paths, and the proc mount. Those come from measurement and from
# moby's own lists rather than from choice;
# docs/profiling/check_test_run_confinement.rb records what dockerd applies to
# a real test-run container.
#
# What a bundle needs that is not here: ociVersion and root, which say where a
# container is run from rather than how it is confined, and the /dev, /sys,
# /dev/pts, /dev/shm and /dev/mqueue mounts dockerd also makes. The
# one part of the boundary still unstated is the per-CPU thermal_throttle mask,
# which dockerd computes from the node it starts on.
#
# docs/profiling/check_crun_run_from_oci_config.rb runs a container from this
# config under crun, and records what that needs.
module CyberDojoShOciConfig
  # The config for the run of one cyber-dojo.sh, taking what identifies that
  # run, as CyberDojoShContainerConfig.create_config does, and the language
  # image's own config, which only the image plane can answer. The whole of the
  # image's config arrives at once rather than a field at a time, because every
  # field of it is per image and so belongs to one lookup.
  def self.config(id, image_name, image_config)
    [
      process(id, image_name, image_config),
      mounts,
      linux(image_name)
    ].reduce(:merge)
  end

  # The process the runtime starts, and what it may do.
  def self.process(id, image_name, image_config)
    {
      'process' => {
        'user' => user,
        'args' => CyberDojoShContainerConfig::COMMAND,
        'cwd' => cwd(image_config),
        # The image's own entries come first, so the run's entries are what
        # wins where both name the same variable. dockerd merges these two for
        # a container; an OCI runtime takes this field as the whole
        # environment, so a config naming only the run's entries starts a
        # process with no PATH.
        'env' => image_config['Env'] + CyberDojoShContainerConfig.env_entries(id, image_name),
        'capabilities' => capabilities(image_name),
        # An OCI runtime takes this as a field of the process, where the docker
        # rendering asks for it as a security option.
        'noNewPrivileges' => true
      }
    }
  end
  private_class_method :process

  # Where the process starts, which dockerd takes from the image and so does
  # this. An OCI runtime takes no relative path, and an image declaring no
  # working directory leaves the field empty, so the root stands in for it.
  def self.cwd(image_config)
    working_dir = image_config['WorkingDir'].to_s
    working_dir.empty? ? '/' : working_dir
  end
  private_class_method :cwd

  # The two tmpfs a kata writes into, and proc. An OCI runtime is given each as
  # a mount of its own, where the docker rendering gives the tmpfs as one map of
  # path to options and mounts proc without being asked.
  def self.mounts
    { 'mounts' => [proc_mount] + tmpfs_mounts }
  end
  private_class_method :mounts

  # Where a kata reads about itself, and where its own confinement is legible:
  # /proc/self/status is what says which capabilities it holds and whether a
  # seccomp filter is loaded. dockerd mounts this into every container it runs.
  def self.proc_mount
    {
      'destination' => '/proc',
      'type' => 'proc',
      'source' => 'proc',
      'options' => %w[nosuid noexec nodev]
    }
  end
  private_class_method :proc_mount

  def self.tmpfs_mounts
    CyberDojoShHostConfig.tmpfs_options.map do |path, options|
      {
        'destination' => path,
        'type' => 'tmpfs',
        'source' => 'tmpfs',
        'options' => options
      }
    end
  end
  private_class_method :tmpfs_mounts

  # The set dockerd leaves a container, which an OCI runtime has to be told in
  # full because it defaults to none of this. Measured rather than chosen:
  # docs/profiling/check_test_run_confinement.rb reads the bounding mask from a
  # container dockerd ran, and capsh decodes it to these.
  BOUNDING_CAPABILITIES = %w[
    CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER CAP_FSETID CAP_KILL CAP_SETGID
    CAP_SETUID CAP_SETPCAP CAP_NET_BIND_SERVICE CAP_NET_RAW CAP_SYS_CHROOT
    CAP_MKNOD CAP_AUDIT_WRITE CAP_SETFCAP
  ].freeze

  # What a kata may do, and what it may come to do. The four sets it holds are
  # empty, which is what the same probe measured: the container runs as the
  # sandbox user, so it is given no capability at all. The bounding set is the
  # ceiling on what it could gain, and no-new-privileges closes the usual route
  # to gaining any.
  def self.capabilities(image_name)
    added = CyberDojoShHostConfig.added_capabilities(image_name).map { |name| "CAP_#{name}" }
    {
      'bounding' => BOUNDING_CAPABILITIES + added,
      'effective' => [],
      'permitted' => [],
      'inheritable' => [],
      'ambient' => []
    }
  end
  private_class_method :capabilities

  # Who the kata runs as. An OCI runtime is told the two ids as numbers, where
  # the docker rendering joins them into one string, so Sandbox is what both
  # read rather than either reading the other.
  def self.user
    {
      'uid' => Sandbox::UID,
      'gid' => Sandbox::GID
    }
  end
  private_class_method :user

  # What the kernel holds the container to. Both ceilings come from the module
  # the docker rendering reads them from, so the two cannot say different
  # numbers.
  def self.linux(image_name)
    {
      'linux' => {
        'resources' => resources,
        'rlimits' => rlimits(image_name),
        'namespaces' => namespaces,
        'seccomp' => seccomp(image_name),
        'maskedPaths' => masked_paths,
        'readonlyPaths' => readonly_paths
      }
    }
  end
  private_class_method :linux

  # The two ceilings the kernel holds the whole container to, as against the
  # rlimits, which bound one process each.
  def self.resources
    {
      'memory' => { 'limit' => CyberDojoShHostConfig::MEMORY_BYTES },
      'pids' => { 'limit' => CyberDojoShHostConfig::MAX_PROCESSES }
    }
  end
  private_class_method :resources

  # Which syscalls a kata may make. dockerd chooses by capability set, allowing
  # a few more where CAP_SYS_PTRACE is present, so the file to read is chosen
  # the same way. Both were generated from dockerd's own profile by its own
  # loader, for amd64, by docs/profiling/resolve_seccomp_profile.go, whose
  # header says what else went into them and when they need making again.
  def self.seccomp(image_name)
    name = CyberDojoShHostConfig.added_capabilities(image_name).empty? ? 'amd64' : 'amd64_with_ptrace'
    JSON.parse(File.read("#{__dir__}/seccomp/#{name}.json"))
  end
  private_class_method :seccomp

  # The paths dockerd hides from every container it runs, by mounting /dev/null
  # over a file and an empty read-only tmpfs over a directory. The list is
  # moby's fixed one, in daemon/pkg/oci/defaults.go. A runtime skips an entry
  # the node does not have, which is why a node's mountinfo shows fewer than
  # these twelve. dockerd masks one more path per CPU,
  # /sys/devices/system/cpu/cpu<n>/thermal_throttle, which it computes from the
  # node it starts on and which is not stated here.
  def self.masked_paths
    %w[
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
    ]
  end
  private_class_method :masked_paths

  # The proc paths dockerd mounts read only into every container it runs, so a
  # kata can read them and cannot write them. The list is moby's, in
  # daemon/pkg/oci/defaults.go, and a container's own mountinfo shows these five
  # as read only binds.
  def self.readonly_paths
    %w[
      /proc/bus
      /proc/fs
      /proc/irq
      /proc/sys
      /proc/sysrq-trigger
    ]
  end
  private_class_method :readonly_paths

  # The namespaces made for the container. An entry naming no path is a new
  # namespace rather than one joined, so the network entry is what the docker
  # rendering asks for as a network mode of none: the kata reaches nothing.
  #
  # There is no user namespace. dockerd puts the container in the one it is
  # in itself, which docs/profiling/check_test_run_confinement.rb measured by
  # finding that id shared while the other six differed. Asking for one here
  # would confine a kata differently rather than the same, so the absence is
  # the translation.
  #
  # The mount namespace is spelled mount, which is the name an OCI runtime
  # takes; /proc spells the same one mnt.
  def self.namespaces
    %w[cgroup ipc mount network pid uts].map { |type| { 'type' => type } }
  end
  private_class_method :namespaces

  # What one kata's processes cannot exceed. An OCI runtime spells each limit
  # RLIMIT_ and the name in upper case, where the docker rendering takes the
  # name as it is, and both give the soft and the hard limit the same value.
  def self.rlimits(image_name)
    CyberDojoShHostConfig.resource_limits(image_name).map do |name, limit|
      {
        'type' => "RLIMIT_#{name.upcase}",
        'soft' => limit,
        'hard' => limit
      }
    end
  end
  private_class_method :rlimits
end
