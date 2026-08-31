# frozen_string_literal: true

# Times one real kata, run both ways on one machine: through the docker daemon
# as the runner does today, and through crun from CyberDojoShOciConfig.
#
# Every crun figure behind ../dropping-the-docker-daemon.md so far timed
# /bin/true over an alpine rootfs. That prices the runtime and not a test-run:
# no tgz goes in, no payload comes back, and the language image is not the one
# a kata runs in. This sends the same tgz the server tests send, through both
# paths, and reads the payload back from each.
#
# Both halves run in this one process on this one machine, which is what makes
# the two columns comparable. Figures taken from different hosts are not: a
# 4-CPU CI runner priced the docker lifecycle at 164ms where a laptop priced it
# at 79ms, so only a same-machine pair says what the change would buy.
#
# What is timed, and what is not. The rootfs is unpacked once, outside the
# timed span, because the design prepares it from a containerd snapshot rather
# than per run. The timed span is what a test-run would pay: writing
# config.json, then crun create, start, wait and delete. Against it, the docker
# span is CyberDojoShRunner.run whole, which is create, attach, start, send and
# read.
#
# The rootfs is reused across iterations rather than overlaid per run, so a
# kata's writes accumulate in it. A real run gets a fresh overlay, priced
# separately by time_crun_on_overlay_vs_plain_rootfs.sh.
#
# What it found, on aarch64 under Docker Desktop, ten runs of each after one
# warm-up run of each:
#
#   crun, one kata      36.5 ms   min 30.7  max 42.2
#   daemon, one kata   108.5 ms   min 95.7  max 155.0
#
# So about 72ms, which is the first figure here taken from a kata rather than
# from /bin/true, and it is close to what the daemon-shaped estimate in
# ../dropping-the-docker-daemon.md predicted by a different route.
#
# The same pair on native amd64, through
# .github/workflows/measure-probes-on-native-amd64.yml, with cgroups disabled
# because crun cannot write them there:
#
#   crun, one kata      65.0 ms   min 63.3  max 67.3
#   daemon, one kata   137.1 ms   min 125.8  max 145.3
#
# Also about 72ms. The two hosts disagree on both absolutes and agree on the
# difference, which is the strongest form this result takes: what the change
# buys survives a different arch, a different kernel and a different daemon
# version, where neither column's own figure does.
#
# The same pair with CRUN_CGROUP_MANAGER=disabled put crun at 33.8 ms, so
# writing the container's cgroups costs about 2.7ms of the 36.5, and a figure
# taken with cgroups off flatters crun by that much as well as leaving the kata
# unlimited.
#
# The two paths agreed on everything asked of them: the same four files,
# sandbox/cyber-dojo.sh, tmp/status, tmp/stderr and tmp/stdout, with the same
# contents, and the same bytes on the container's own stderr. That agreement is
# what makes the pair of timings mean anything; a faster path answering
# something else would be no result at all.
#
# Not measured here. The rootfs is unpacked once and reused, so nothing prices
# a per-run overlay, which time_crun_on_overlay_vs_plain_rootfs.sh does
# separately. The kata is one line of shell, so neither column carries a real
# language's compile. And this is one machine: the same comparison belongs on
# native amd64, where .github/workflows/measure-probes-on-native-amd64.yml runs
# the other probes.
#
# Runs inside the runner image, which is where crun is installed and where the
# socket is mounted. The privileges are the ones
# check_crun_run_from_oci_config.rb found crun needs:
#
#   docker run --rm \
#     --cap-add SYS_ADMIN --cap-add NET_ADMIN \
#     --security-opt seccomp=unconfined --cgroupns=private \
#     --tmpfs /tmp:rw,exec,size=2g \
#     --volume /sys/fs/cgroup:/sys/fs/cgroup:rw \
#     --volume <repo>/runner:/runner:ro \
#     --volume /var/run/docker.sock:/var/run/docker.sock \
#     --entrypoint='' \
#     cyberdojo/runner:<tag> ruby /runner/docs/profiling/time_kata_under_crun_vs_daemon.rb

require 'fileutils'
require 'json'
require 'open3'
require_relative '../../source/server/cyber_dojo_sh_oci_config'
require_relative '../../source/server/cyber_dojo_sh_runner'
require_relative '../../source/server/docker_daemon'
require_relative '../../source/server/externals/docker_socket'
require_relative '../../source/server/externals/monotonic_clock'
require_relative '../../source/server/home_files'
require_relative '../../source/server/lib/tgz'
require_relative '../../source/server/sandbox'

include HomeFiles

IMAGE_NAME = ARGV[0] || 'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a'
ID = 'sX9k2mQ4pR'
RUNS = 10
MAX_SECONDS = 10
BUNDLE_DIR = '/tmp/kata-bundle'

# How crun is asked to apply the memory and pids limits, if at all. Whether a
# container can write its own cgroup varies by host: what a developer machine
# grants through a private cgroup namespace and a writable /sys/fs/cgroup, a
# CI runner refuses. CRUN_CGROUP_MANAGER=disabled buys a timing on a host where
# crun cannot write cgroups, at the price of a container held to neither limit,
# so a figure taken that way is not a figure for a confined kata.
CGROUP_MANAGER =
  if ENV['CRUN_CGROUP_MANAGER'].to_s.empty?
    []
  else
    ["--cgroup-manager=#{ENV['CRUN_CGROUP_MANAGER']}"]
  end

# The smallest kata that still exercises the whole protocol: the tgz is
# unpacked, cyber_dojo_main.sh runs it, and a payload comes back.
CYBER_DOJO_SH = "echo hello\n"

ProbeContext = Struct.new(:http, :clock) do
  def docker
    @docker ||= DockerDaemon.new(self)
  end
end

# What runner.rb sends in, built the way the server tests build it.
def kata_tgz
  files = Sandbox.in({ 'cyber-dojo.sh' => CYBER_DOJO_SH })
  TGZ.of(files.merge(home_files(Sandbox::DIR, 50 * 1024)))
end

def image_config(context)
  code, body = context.http.request('GET', "/images/#{IMAGE_NAME}/json")
  abort "image inspect answered #{code}: #{body}" unless code.between?(200, 299)

  JSON.parse(body)['Config']
end

# The rootfs both paths' kata sees, read out of the image as a tar. Unpacked
# once: preparing it is the image plane's work, not a test-run's.
def unpack_rootfs(context, rootfs_dir)
  code, body = context.docker.create_container({ 'Image' => IMAGE_NAME, 'Entrypoint' => [] })
  abort "create answered #{code}: #{body}" unless code.between?(200, 299)

  container_id = JSON.parse(body)['Id']
  code, tar = context.docker.read_file(container_id, '/')
  context.docker.remove_container(container_id)
  abort "archive answered #{code}" unless code.between?(200, 299)

  FileUtils.mkdir_p(rootfs_dir)
  IO.popen(['tar', '--extract', '--directory', rootfs_dir], 'wb') { |io| io.write(tar) }
end

# The bundle config, plus the two fields that say where the container runs
# rather than how it is confined.
def bundle_config(context)
  CyberDojoShOciConfig.config(ID, IMAGE_NAME, image_config(context)).merge(
    'ociVersion' => '1.0.2',
    'root' => { 'path' => "#{BUNDLE_DIR}/rootfs", 'readonly' => false },
    'hostname' => 'cyber-dojo'
  )
end

# One kata under crun, answering what it wrote and how long the span took. The
# config write is inside the span because a real run writes one per test-run.
def crun_run(config, tgz, run_index)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  File.write("#{BUNDLE_DIR}/config.json", JSON.generate(config))
  stdout, stderr, status = Open3.capture3(
    'crun', *CGROUP_MANAGER, 'run', '--no-new-keyring',
    '--bundle', BUNDLE_DIR, "kata-#{ID}-#{run_index}",
    stdin_data: tgz
  )
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  [((t1 - t0) * 1000).round(1), stdout, stderr, status.exitstatus]
end

# One kata through the daemon, the way a test-run goes today.
def daemon_run(context, tgz, run_index)
  runner = CyberDojoShRunner.new(context)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = runner.run(ID, IMAGE_NAME, "kata_daemon_#{run_index}", MAX_SECONDS, tgz)
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  [((t1 - t0) * 1000).round(1), result]
end

def mean(values)
  (values.sum / values.size).round(1)
end

def report(label, spans)
  puts format('%-28s %8s ms   min %s  max %s',
              label, mean(spans), spans.min, spans.max)
end

context = ProbeContext.new(DockerSocket.new, MonotonicClock.new)
tgz = kata_tgz

puts "image: #{IMAGE_NAME}"
puts "kata: #{CYBER_DOJO_SH.strip}"
puts "tgz bytes: #{tgz.bytesize}"
puts "runs: #{RUNS}"
puts "cgroup manager: #{CGROUP_MANAGER.empty? ? "crun's own default" : ENV['CRUN_CGROUP_MANAGER']}"
puts

FileUtils.rm_rf(BUNDLE_DIR)
unpack_rootfs(context, "#{BUNDLE_DIR}/rootfs")
config = bundle_config(context)

# One run of each before timing, so neither column pays for a cold cache the
# other has already warmed. They are also what the two paths are compared on:
# a timing means nothing unless both paths answer the same thing.
_, crun_payload, crun_stderr, crun_status = crun_run(config, tgz, 'warmup')
_, daemon_result = daemon_run(context, tgz, 'warmup')

# The payload is a tgz of the files a kata left behind, so what the two paths
# agree about is those files rather than the bytes carrying them: a tar header
# holds a timestamp, and two runs are never at the same instant.
def files_of(payload)
  TGZ.files(payload)
rescue StandardError => e
  { 'PAYLOAD DID NOT PARSE' => e.message }
end

crun_files = files_of(crun_payload)
daemon_files = files_of(daemon_result[:stdout])

puts "crun exit: #{crun_status}"
puts "daemon timed out: #{daemon_result[:timed_out]}"
# What the container's own stderr said, which is not the same as the stderr the
# kata left in tmp/stderr. Both paths carry it, so it is compared rather than
# reported for one of them.
puts "crun stderr:   #{crun_stderr.inspect}"
puts "daemon stderr: #{daemon_result[:stderr].inspect}"
puts "crun files: #{crun_files.keys.sort.join(' ')}"
puts "daemon files: #{daemon_files.keys.sort.join(' ')}"

if crun_files == daemon_files
  puts 'the two paths answer the same files, with the same contents'
else
  differing = (crun_files.keys | daemon_files.keys).reject do |key|
    crun_files[key] == daemon_files[key]
  end
  puts "the two paths differ on: #{differing.sort.join(' ')}"
  differing.sort.each do |key|
    puts "  #{key} crun:   #{crun_files[key].inspect}"
    puts "  #{key} daemon: #{daemon_files[key].inspect}"
  end
end
puts

crun_spans = []
daemon_spans = []
RUNS.times do |i|
  span, stdout, stderr, exit_status = crun_run(config, tgz, i)
  if exit_status.zero?
    crun_spans << span
  else
    puts "crun run #{i} exited #{exit_status}: #{stderr}"
  end
  puts "crun run #{i} said nothing" if exit_status.zero? && stdout.empty?

  span, result = daemon_run(context, tgz, i)
  daemon_spans << span
  puts "daemon run #{i} timed out" if result[:timed_out]
end

puts
report('crun, one kata', crun_spans) unless crun_spans.empty?
report('daemon, one kata', daemon_spans) unless daemon_spans.empty?

# A column with nothing in it is a failed measurement, and a probe that says so
# only in its output is one a CI step reports as green.
if crun_spans.empty? || daemon_spans.empty?
  warn 'ERROR: one path produced no timings'
  exit 1
end
