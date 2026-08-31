# frozen_string_literal: true

# Runs a container under crun from CyberDojoShOciConfig, to find out what a
# bundle built from that config still lacks.
#
# ../dropping-the-docker-daemon.md step 4 is where crun first executes anything.
# The config states what the two config classes state, plus the capabilities,
# namespaces, seccomp profile and proc paths dockerd applies as defaults. What
# it does not state is everything a bundle needs that is not part of confining a
# kata: the OCI version, where the rootfs is, and the process's working
# directory. Those are added here, so that what fails is the config rather than
# the bundle around it.
#
# The rootfs comes from the daemon, by creating a container from the language
# image and reading its whole filesystem back as a tar. That is slow and is not
# the design, which prepares a containerd snapshot instead. It is used because
# it needs nothing the runner does not already have, which keeps this probe
# about crun and the config rather than about the image plane.
#
# The command is a report rather than a kata. Whether crun accepts the config is
# the question here; carrying a kata's tgz in and its payload back out is the
# other half of step 4 and is not measured.
#
# What it found. A container runs from this config: exit 0, aarch64, as
# uid 41966 gid 51966, with the run's CYBER_DOJO_ID and the image's PATH, and
# /proc/self/status reporting Seccomp 2 with one filter, which is what
# check_test_run_confinement.rb reads from a container dockerd ran. The profile
# committed for amd64 loads and is enforced on an aarch64 container, so the
# architectures it names are a matter of saying the true thing rather than
# something that stops a run.
#
# Two things the config lacked, both found here and both since stated: it
# carried only the run's three env entries, so the process could not find bash,
# and it mounted no proc, so nothing inside could read its own confinement.
# Still unstated are the /dev, /sys, /dev/pts, /dev/shm and /dev/mqueue mounts
# dockerd makes. process.cwd was a third, and the config states it now: the perl
# image declares /usr/src/app, so a bundle defaulting that to / would start a
# kata somewhere dockerd would not.
#
# What the runner container needs to drive crun, none of which it holds today:
# CAP_SYS_ADMIN, without which clone refuses to make the namespaces;
# CAP_NET_ADMIN, without which the loopback interface cannot be brought up; a
# writable /sys/fs/cgroup, without which the memory and pids limits cannot be
# applied; a bundle on a mount of its own, since pivot_root refuses a new root
# on the mount it is already on; and an outer seccomp profile permitting
# pivot_root, which dockerd's default refuses. crun also needs
# --no-new-keyring, because dockerd's profile refuses the runner keyctl.
#
# Runs inside the runner image, which is where crun is installed and where the
# socket is mounted:
#
#   docker run --rm \
#     --volume <repo>/runner:/runner:ro \
#     --volume /var/run/docker.sock:/var/run/docker.sock \
#     --entrypoint='' \
#     cyberdojo/runner:<tag> ruby /runner/docs/profiling/check_crun_run_from_oci_config.rb
#
# An image name can follow, and replaces the one reported by default.

require 'fileutils'
require 'json'
require 'open3'
require_relative '../../source/server/cyber_dojo_sh_container_config'
require_relative '../../source/server/cyber_dojo_sh_oci_config'
require_relative '../../source/server/docker_daemon'
require_relative '../../source/server/externals/docker_socket'

# An ordinary image, carrying none of the extra capability a clang image gets.
DEFAULT_IMAGE_NAME = 'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a'

# The id a test-run is given, which reaches the container as CYBER_DOJO_ID.
ID = 'sX9k2mQ4pR'

# Where the bundle is built. The runner's own /tmp is a tmpfs, which is writable
# where the rest of its filesystem is not.
BUNDLE_DIR = '/tmp/crun-bundle'

# Where the bundle crun generates for itself is built, so that it neither
# overwrites the one above nor is refused for finding a config.json already
# there. It shares the rootfs rather than unpacking a second copy.
SPEC_BUNDLE_DIR = '/tmp/crun-spec-bundle'

# What the container runs instead of a kata. Says who it is, what it was given,
# and whether the sandbox the config names is there to be written.
REPORT = <<~BASH
  echo "arch: $(uname -m)"
  echo "id: $(id)"
  echo "cwd: $(pwd)"
  echo "PATH: [${PATH}]"
  echo "CYBER_DOJO_ID: [${CYBER_DOJO_ID}]"
  echo "seccomp: $(grep -E '^Seccomp' /proc/self/status | tr '\\n' ' ')"
BASH

# What DockerDaemon reaches the daemon through. Context is what the server uses
# for this, and it also builds services whose gems this probe does not need.
ProbeContext = Struct.new(:http) do
  def docker
    @docker ||= DockerDaemon.new(self)
  end
end

# Answers the tar of the whole filesystem of a container created from
# image_name. The container is never started: the archive endpoint reads a
# created container, so nothing has to run for its files to be readable.
def image_rootfs_tar(docker, image_name)
  code, body = docker.create_container({ 'Image' => image_name, 'Entrypoint' => [] })
  abort "create answered #{code}: #{body}" unless code.between?(200, 299)

  container_id = JSON.parse(body)['Id']
  code, tar = docker.read_file(container_id, '/')
  docker.remove_container(container_id)
  abort "archive answered #{code}" unless code.between?(200, 299)

  tar
end

# Unpacks the image's filesystem into the bundle, which is what crun runs the
# process over.
def unpack_rootfs(docker, image_name, rootfs_dir)
  FileUtils.rm_rf(BUNDLE_DIR)
  FileUtils.mkdir_p(rootfs_dir)
  tar = image_rootfs_tar(docker, image_name)
  IO.popen(['tar', '--extract', '--directory', rootfs_dir], 'wb') do |io|
    io.write(tar)
  end
end

# What the image itself declares. The env is where PATH comes from, and the
# working directory is where dockerd starts a container. One read answers both,
# which is what makes them one cache rather than two. Only the image plane can
# answer this, and this probe is that plane: it asks the daemon, where the
# design asks containerd.
def image_config(context, image_name)
  code, body = context.http.request('GET', "/images/#{image_name}/json")
  abort "image inspect answered #{code}: #{body}" unless code.between?(200, 299)

  JSON.parse(body)['Config']
end

# The config, plus the three fields a bundle needs that say nothing about how a
# kata is confined, and the report in place of the kata's command.
def bundle_config(context, image_name)
  config = CyberDojoShOciConfig.config(ID, image_name, image_config(context, image_name))
  config['process'] = config['process'].merge(
    'args' => ['bash', '-c', REPORT],
    'terminal' => false
  )
  config.merge(
    'ociVersion' => '1.0.2',
    'root' => { 'path' => 'rootfs', 'readonly' => false },
    'hostname' => 'cyber-dojo'
  )
end

# Runs the bundle, saying what crun said. A refusal is the answer this probe is
# after, so it is printed rather than raised.
def report(context, image_name)
  puts "image: #{image_name}"
  unpack_rootfs(context.docker, image_name, "#{BUNDLE_DIR}/rootfs")
  File.write("#{BUNDLE_DIR}/config.json", JSON.pretty_generate(bundle_config(context, image_name)))

  # The runner is itself a container, and dockerd's default seccomp refuses it
  # keyctl, so crun cannot make the container a keyring session of its own.
  # dockerd does not give a test-run container one either.
  stdout, stderr, status = Open3.capture3(
    'crun', 'run', '--no-new-keyring', '--bundle', BUNDLE_DIR, "probe-#{ID}"
  )
  puts "crun exit: #{status.exitstatus}"
  puts stdout unless stdout.empty?
  puts "stderr: #{stderr}" unless stderr.empty?
end

# The same rootfs under crun's own generated config, which says what a bundle
# looks like when nothing here wrote it. Run beside the report above, it says
# whether a refusal belongs to this config or to the container the runner is.
def report_crun_own_spec
  puts 'crun spec, same rootfs'
  FileUtils.rm_rf(SPEC_BUNDLE_DIR)
  FileUtils.mkdir_p(SPEC_BUNDLE_DIR)
  _, spec_stderr, spec_status = Open3.capture3('crun', 'spec', '--bundle', SPEC_BUNDLE_DIR)
  unless spec_status.success?
    puts "crun spec failed: #{spec_stderr}"
    return
  end

  spec = JSON.parse(File.read("#{SPEC_BUNDLE_DIR}/config.json"))
  spec['process']['args'] = ['/bin/sh', '-c', 'echo ran; id']
  # The generated spec asks for a terminal, and this probe is not run from one.
  spec['process']['terminal'] = false
  spec['root'] = { 'path' => "#{BUNDLE_DIR}/rootfs", 'readonly' => false }
  File.write("#{SPEC_BUNDLE_DIR}/config.json", JSON.pretty_generate(spec))

  stdout, stderr, status = Open3.capture3(
    'crun', 'run', '--no-new-keyring', '--bundle', SPEC_BUNDLE_DIR, "spec-#{ID}"
  )
  puts "crun exit: #{status.exitstatus}"
  puts stdout unless stdout.empty?
  puts "stderr: #{stderr}" unless stderr.empty?
end

report(ProbeContext.new(DockerSocket.new), ARGV[0] || DEFAULT_IMAGE_NAME)
report_crun_own_spec
