require 'json'
require_relative 'cyber_dojo_sh_container_config'
require_relative 'cyber_dojo_sh_host_config'
require_relative 'sandbox'

# The OCI runtime config for one run of cyber-dojo.sh, saying what
# CyberDojoShContainerConfig says to the docker daemon.
#
# Nothing runs it. It is here so that the field for field mapping onto an OCI
# runtime is written down, and checked by a test, while dockerd is still what
# runs a kata. See docs/dropping-the-docker-daemon.md
#
# It is not a config a container may be run from. There is no
# process.capabilities, no seccomp profile, and no namespace but the network
# one, because dockerd applies those as defaults that neither config class
# names, so there is nothing here to translate. A runtime handed this config
# would confine a kata differently from the way dockerd confines it, and more
# weakly, in a way no test of a kata's result can see. Deciding what they hold
# is the open question of that document;
# docs/profiling/check_test_run_confinement.rb records what dockerd applies
# today.
module CyberDojoShOciConfig
  # The config for the run of one cyber-dojo.sh, taking what identifies that
  # run, as CyberDojoShContainerConfig.create_config does.
  def self.config(id, image_name)
    [
      process(id, image_name),
      mounts,
      linux(image_name)
    ].reduce(:merge)
  end

  # The process the runtime starts, and what it may do.
  def self.process(id, image_name)
    {
      'process' => {
        'user' => user,
        'args' => CyberDojoShContainerConfig::COMMAND,
        'env' => CyberDojoShContainerConfig.env_entries(id, image_name),
        'capabilities' => capabilities(image_name),
        # An OCI runtime takes this as a field of the process, where the docker
        # rendering asks for it as a security option.
        'noNewPrivileges' => true
      }
    }
  end
  private_class_method :process

  # The two tmpfs a kata writes into. An OCI runtime is given each as a mount
  # of its own, where the docker rendering gives them as one map of path to
  # options.
  def self.mounts
    {
      'mounts' => CyberDojoShHostConfig.tmpfs_options.map do |path, options|
        {
          'destination' => path,
          'type' => 'tmpfs',
          'source' => 'tmpfs',
          'options' => options
        }
      end
    }
  end
  private_class_method :mounts

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
        'seccomp' => seccomp(image_name)
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
