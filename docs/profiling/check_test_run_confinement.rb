# frozen_string_literal: true

# Records the confinement the kernel applies to a test-run container under
# dockerd: the capability masks, no-new-privileges, the seccomp mode and filter
# count, and what happens when syscalls dockerd's default profile blocks are
# attempted.
#
# ../dropping-the-docker-daemon.md proposes driving crun directly and taking the
# daemon off the traffic-light path. A container created that way cannot be
# shown to confine a kata as well as today's one unless today's is written down
# while dockerd is still the thing creating it. That document's staging makes
# this record its first step, and gates the new path against it at step 4.
#
# The container is created from CyberDojoShContainerConfig, the module a real
# test-run is created from, so what is recorded is the running configuration
# rather than a copy of it that can drift. Only Cmd differs: where a test-run
# unpacks a tgz and runs cyber_dojo_main.sh, this reports on itself instead.
# What the kernel enforces comes from the create rather than from the command.
#
# Two processes are reported. The config asks for Init, so PID 1 is tini and
# /proc/1/status describes tini; /proc/self/status describes a process where a
# kata's own cyber-dojo.sh runs.
#
# An image whose name starts ghcr.io/cyber-dojo-languages/clang is the only kind
# given CAP_SYS_PTRACE, so an ordinary image and a clang image are both
# reported, and the difference between them should be that one capability.
#
# What it found. Both processes report the same thing, so tini and a kata run
# equally confined: CapInh, CapPrm, CapEff and CapAmb all empty, NoNewPrivs 1,
# Seccomp 2, which is filter mode, and one filter loaded. The permitted and
# effective sets are empty because the container runs as the sandbox user, so
# the bounding set is what actually bounds a kata.
#
# The two bounding sets are a80425fb and a80c25fb, differing by 0x00080000,
# which is bit 19, CAP_SYS_PTRACE. That is the clang image's one extra
# capability and nothing else, which is what the config says and is now
# measured rather than assumed.
#
# Every attempted syscall was refused, in both images. insmod is in neither, so
# module loading is unattempted rather than shown blocked.
#
# The capability masks decode, through capsh, to the fourteen dockerd leaves a
# container: chown, dac_override, fowner, fsetid, kill, setgid, setuid, setpcap,
# net_bind_service, net_raw, sys_chroot, mknod, audit_write, setfcap. A clang
# image adds sys_ptrace and nothing else. Since the permitted and effective sets
# are empty, a kata holds none of them; the bounding set is the ceiling on what
# it could come to hold, which no-new-privileges already closes the usual route
# to.
#
# dockerd hides parts of proc from a container, by bind mounting /dev/null over
# them rather than by refusing them: /proc/kcore and /proc/timer_list both read
# as empty here, where the first would be refused to this user and the second
# would answer text. /proc/latency_stats is absent from this kernel altogether,
# and /sys/firmware is a directory, which this cannot measure the same way.
#
# Of the seven namespaces, six differ from the reporting container's and are
# therefore made for the container: cgroup, ipc, mnt, net, pid and uts. The user
# namespace is the reporting container's own, so dockerd shares it rather than
# making one, which is why a kata cannot unshare CLONE_NEWUSER and why an OCI
# config that asked for a user namespace would be a change in behaviour rather
# than a translation of this one.
#
# The two default images do not resolve to the same architecture here: the perl
# one ran aarch64 and the clang one ran x86_64, emulated. The masks and the
# filter count agree across that difference, but the syscalls a filter names are
# numbered per architecture, so a comparison drawn against this record is
# soundest read a row at a time, arch against the same arch.
#
# The syscall attempts need a tool in the image to make the call. Where the
# image has no such tool the attempt says so rather than being read as a syscall
# that was allowed. The masks and the filter count come from /proc and are
# always present, so an absent tool costs detail rather than the record itself.
#
# Runs in a ruby container rather than on the host, because the source it
# requires wants ruby 3.2 or later for IO#timeout=, which is older than the ruby
# a mac ships. It needs no gems, so any stock ruby image will do. The socket is
# mounted because creating the container being reported on is the whole point.
#
#   docker run --rm \
#     --volume <repo>/runner:/runner:ro \
#     --volume /var/run/docker.sock:/var/run/docker.sock \
#     ruby:3.4-alpine ruby /runner/docs/profiling/check_test_run_confinement.rb
#
# Image names can follow, and replace the two reported by default.

require 'json'
require_relative '../../source/server/cyber_dojo_sh_container_config'
require_relative '../../source/server/deadline_reader'
require_relative '../../source/server/docker_attach_frames'
require_relative '../../source/server/docker_daemon'
require_relative '../../source/server/externals/docker_socket'
require_relative '../../source/server/externals/monotonic_clock'

# An ordinary image and a clang image, which are the two confinements the
# config produces.
DEFAULT_IMAGE_NAMES = [
  'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a',
  'ghcr.io/cyber-dojo-languages/clang_assert:ed23233'
].freeze

# Long enough that a slow node still answers, short enough that a container
# which says nothing does not hold the probe open.
MAX_SECONDS = 10

# The id a test-run is given, which reaches the container as CYBER_DOJO_ID.
ID = 'sX9k2mQ4pR'

# The status fields that say what the kernel applies. The capability masks say
# what the process may do, NoNewPrivs says it cannot gain more, and the seccomp
# pair says whether a filter is loaded and how many.
STATUS_FIELDS = 'CapInh|CapPrm|CapEff|CapBnd|CapAmb|NoNewPrivs|Seccomp|Seccomp_filters'

# Every namespace a process can be in, so that one shared with the reporter is
# reported rather than left out of the comparison.
NAMESPACES = %w[cgroup ipc mnt net pid user uts].freeze

# What the container runs instead of a kata. Reports both processes' status
# fields, then attempts syscalls dockerd's default profile blocks, saying for
# each whether it was refused, allowed, or had no tool to make the call.
DUMP = <<~BASH
  echo "arch: $(uname -m)"

  echo "== pid 1 (tini)"
  grep -E '^(#{STATUS_FIELDS}):' /proc/1/status

  echo "== cyber-dojo.sh process"
  grep -E '^(#{STATUS_FIELDS}):' /proc/self/status

  echo "== namespaces"
  for ns in #{NAMESPACES.join(' ')}; do
    echo "${ns}: $(readlink /proc/self/ns/${ns})"
  done

  # A masked path is /dev/null bind mounted over it, so reading one succeeds and
  # yields nothing. That is not the same as a path being readable, and not the
  # same as one being refused, so the byte count is what tells the three apart.
  echo "== paths dockerd hides"
  for path in /proc/kcore /proc/latency_stats /proc/timer_list /sys/firmware; do
    if [ ! -e "${path}" ]; then
      echo "${path}: absent"
    elif [ -d "${path}" ]; then
      # head answers nothing for a directory, and wc then counts that nothing,
      # which would read as a masked path rather than as no measurement.
      echo "${path}: a directory, not measured here"
    elif ! bytes=$(head -c 64 "${path}" 2>/dev/null | wc -c); then
      echo "${path}: refused"
    else
      echo "${path}: read ${bytes} bytes"
    fi
  done

  echo "== blocked syscall attempts"
  attempt()
  {
    local name="${1}"
    local tool="${2}"
    shift 2
    if ! command -v "${tool}" > /dev/null 2>&1; then
      echo "${name}: no ${tool} in this image"
      return
    fi
    # Only the error is wanted. A refused call can still write to stdout, and
    # printing that beside the refusal reads as though the call had worked.
    local output
    if output="$("$@" 2>&1 > /dev/null)"; then
      echo "${name}: ALLOWED"
    else
      echo "${name}: refused, ${output}"
    fi
  }

  attempt 'unshare CLONE_NEWUSER' unshare unshare --user true
  attempt 'unshare CLONE_NEWNS'   unshare unshare --mount true
  attempt 'mount tmpfs'           mount   mount -t tmpfs tmpfs /tmp
  attempt 'kernel module load'    insmod  insmod /dev/null
  attempt 'set system clock'      date    date --set '@0'
BASH

# What DockerDaemon reaches the daemon through, holding the two externals it
# and the read below need. Context is what the server uses for this, and it
# also builds the services, whose gems are in the runner image rather than in
# the ruby a probe on the host runs under.
ProbeContext = Struct.new(:http, :clock) do
  # The daemon, reached through http, the way Context holds its own.
  def docker
    @docker ||= DockerDaemon.new(self)
  end
end

# The create body of a real test-run, with the kata's command replaced by the
# report. Every other key is the one the runner would send.
def create_config(image_name)
  CyberDojoShContainerConfig.create_config(ID, image_name)
                            .merge('Cmd' => ['bash', '-c', DUMP])
end

# Answers the container's id, having created it. A refusal here means nothing
# below would describe anything, so it stops the probe and says what the daemon
# said.
def create_container(docker, image_name)
  code, body = docker.create_container(create_config(image_name))
  unless code.between?(200, 299)
    warn "ERROR: create answered #{code} for #{image_name}: #{body}"
    exit 1
  end
  JSON.parse(body)['Id']
end

# Answers what the container wrote. Attaching before starting is what stops its
# first bytes being written before anything is listening, and closing the
# writing half is what lets a command that reads stdin see an end of file.
def output_of(context, container_id)
  stream = context.docker.attach_container(container_id)
  context.docker.start_container(container_id)
  stream.close_write
  reader = DeadlineReader.new(stream, max_seconds: MAX_SECONDS, clock: context.clock)
  DockerAttachFrames.demultiplex(reader)
end

# Reports one image's confinement, naming the image so that two reports read
# side by side say which is which.
# The namespaces of the process doing the reporting. This container is alive
# for as long as the one it reports on, so an id it shares with that container
# is a namespace the two are really in together. Comparing two test-run
# containers instead would not say that: the kernel reuses the inode number of
# a namespace the moment the container holding it exits.
def probe_namespaces
  NAMESPACES.map { |ns| "#{ns}: #{File.readlink("/proc/self/ns/#{ns}")}" }
end

def report(context, image_name)
  puts "image: #{image_name}"
  container_id = create_container(context.docker, image_name)
  stdout, stderr = output_of(context, container_id)
  puts stdout
  puts stderr unless stderr.empty?
  puts '== namespaces of the reporting container'
  puts probe_namespaces
  puts
end

context = ProbeContext.new(DockerSocket.new, MonotonicClock.new)
image_names = ARGV.empty? ? DEFAULT_IMAGE_NAMES : ARGV
image_names.each { |image_name| report(context, image_name) }
