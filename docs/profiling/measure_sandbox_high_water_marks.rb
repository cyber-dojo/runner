# frozen_string_literal: true

# What one test-run of a heavy LTF actually uses, against the five limits
# CyberDojoShHostConfig sets: the two tmpfs sizes, the fsize ulimit, the nofile
# ulimit and the nproc ulimit, plus the container's memory.
#
# Why it is worth measuring. The tmpfs sizes were 50M until d5959d62 raised both
# to 250M, and that commit records no reason. The fsize ulimit is 256MB, which is
# above the 250M tmpfs it would have to fit in, so it cannot bite as written.
# docs/pre-started-container-pool.md sizes its cap against what a running
# container costs, so the ceilings being far above the marks is the difference
# between the cap being generous and being a guess.
#
# The sample is the compiled and heavy end, chosen because only the maximum
# matters and a cheap LTF cannot raise it. Every figure is one run of one kata,
# the start-point's own visible_files, which is the smallest a sandbox ever is:
# a learner who has been working for an hour has written more.
#
# What it measures, inside the container, before it exits:
#
#   kata status      what cyber-dojo.sh exited with, so a limit that broke a
#                    build is read here rather than inferred from a size
#   sandbox bytes    du of the sandbox dir
#   sandbox files    how many, against the nofile ulimit's 1024
#   largest file     against the fsize ulimit's 256MB
#   tmp bytes        du of /tmp, the second tmpfs
#   pids peak        the cgroup's own high-water mark, against nproc's 1024
#   fds now          open descriptors at the end, a snapshot and not a peak
#   memory peak      the cgroup's high-water mark, against Memory's 2GB
#
# The kata runs as cyber_dojo_main.sh runs it, minus the exit trap: nothing is
# tarred out, because what is wanted is the sandbox as the kata left it rather
# than what a test-run would answer.
#
# What it found, one run of each start-point's own kata, on aarch64 under
# Docker Desktop. Every ceiling has one to two orders of magnitude spare:
#
#   limit          set to    worst of the seven
#   /sandbox       250M      8.7MB   Python, pytest
#   /tmp           250M      1.2MB   JavaScript, Jasmine
#   fsize          256MB     583KB   C++ (g++), GoogleTest
#   nproc          1024      36      C#, NUnit
#   nofile         1024      25
#   Memory         2GB       260MB   C++ (g++), GoogleTest
#
# fsize is the odd one. At 256MB it is above the 250M tmpfs any file it bounds
# has to fit inside, so the tmpfs refuses a write before the ulimit does and the
# limit cannot fire as written.
#
# All 82 start-points, run with the argument all, put the maxima higher than
# the sample did, and one of them close:
#
#   limit          set to    worst of 82
#   /sandbox       64M       20.0MB   Python, unittest-approval
#   /tmp           64M       1.2MB    JavaScript, Jasmine
#   fsize          16MB      3.4MB    C++ (g++), Cucumber
#   Memory         768MB     719.9MB  Julia, test
#
# Julia's 6% margin against Memory is the tightest thing here, and the seven of
# the sample said 260MB, so a sample cannot size these.
#
# The status column is what says whether a limit broke a build, and it has to be
# read as a comparison rather than a value. Most start-point katas are red by
# design, so 1 and 2 are ordinary. What matters is a status that moves when a
# limit moves: elixir_exunit answers 2 with fsize at 256MB and 153, which is
# SIGXFSZ, with it at 16MB, and moving the tmpfs sizes alone does not change it.
# Its sandbox holds 16KB either way, so what fsize refused was a write this
# probe cannot see.
#
# Two things to hold against these figures. The sampled peaks undercount:
# C++ (g++), GoogleTest reports a sampled peak of 72KB and a final 648KB, which
# says the sampler missed the build, so each peak is a floor rather than a mark.
# And a start-point's kata is the smallest a sandbox ever is; a learner an hour
# into an exercise has written more, though not 28x more.
#
# Runs inside the runner image, which is where the socket is mounted:
#
#   docker run --rm \
#     --volume <repo>/runner:/runner:ro \
#     --volume /var/run/docker.sock:/var/run/docker.sock \
#     --entrypoint='' \
#     cyberdojo/runner:<tag> ruby /runner/docs/profiling/measure_sandbox_high_water_marks.rb
#
# Display names can follow, and replace the sample below. The single argument
# all measures every start-point in the fixture, pulling whatever the node
# lacks, which is how the sample's claim to hold the maximum gets tested.

require 'json'
require_relative '../../source/server/cyber_dojo_sh_container_config'
require_relative '../../source/server/docker_attach_frames'
require_relative '../../source/server/docker_daemon'
require_relative '../../source/server/deadline_reader'
require_relative '../../source/server/externals/docker_socket'
require_relative '../../source/server/externals/monotonic_clock'
require_relative '../../source/server/home_files'
require_relative '../../source/server/lib/tgz'
require_relative '../../source/server/sandbox'

include HomeFiles

MANIFESTS = "#{__dir__}/../../test/data/languages_start_points.manifests.json"

# The compiled and heavy end. A build that writes object files, jars, binaries
# or a target directory is what could approach a 250M tmpfs; an interpreter
# reading three files cannot.
SAMPLE = [
  'C#, NUnit',
  'C++ (g++), GoogleTest',
  'Go, testing',
  'Java, JUnit',
  'Rust, test',
  'JavaScript, Jasmine',
  'Python, pytest'
].freeze

ID = 'sX9k2mQ4pR'
MAX_SECONDS = 120

# Runs the kata, then reports the marks. du answers KB, so every byte figure
# here is KB and named as such. The cgroup files are read rather than sampled
# where the kernel keeps the high-water mark itself.
MEASURE = <<~BASH
  # Sampled rather than read, because a tmpfs keeps no high-water mark and most
  # start-points delete what they built before the run ends. Measuring after the
  # kata therefore measures the tidied sandbox: 20KB for a C# build that peaked
  # at 161MB of memory. A tenth of a second is short against a build and long
  # enough not to perturb one.
  peak_sandbox=0
  peak_tmp=0
  sample()
  {
    while true; do
      s=$(du -sk #{Sandbox::DIR} 2> /dev/null | cut -f1)
      t=$(du -sk /tmp 2> /dev/null | cut -f1)
      [ "${s:-0}" -gt "${peak_sandbox}" ] && peak_sandbox=${s}
      [ "${t:-0}" -gt "${peak_tmp}" ] && peak_tmp=${t}
      echo "${peak_sandbox} ${peak_tmp}" > /tmp/.peaks
      sleep 0.1
    done
  }
  sample &
  sampler=$!

  # The kata's own output is discarded, and its status is not: a limit low
  # enough to break a build shows up here rather than in the sizes, where a
  # build that wrote nothing looks the same as one that had nothing to write.
  cd #{Sandbox::DIR} && bash ./cyber-dojo.sh > /dev/null 2>&1
  kata_status=$?

  kill "${sampler}" 2> /dev/null
  read -r peak_sandbox peak_tmp < /tmp/.peaks
  echo "kata_status: ${kata_status}"
  echo "peak_sandbox_kb: ${peak_sandbox}"
  echo "peak_tmp_kb: ${peak_tmp}"
  echo "sandbox_kb: $(du -sk #{Sandbox::DIR} | cut -f1)"
  echo "sandbox_files: $(find #{Sandbox::DIR} -type f | wc -l)"
  # wc prints a total line last when given more than one file, so the largest
  # file is the second from the end, and the only line when there is just one.
  echo "largest_file_bytes: $(find #{Sandbox::DIR} -type f | tr '\\n' '\\0' \\
    | xargs -0 wc -c | sort -n | tail -n 2 | head -n 1 | awk '{print $1}')"
  echo "tmp_kb: $(du -sk /tmp | cut -f1)"
  echo "pids_peak: $(cat /sys/fs/cgroup/pids.peak 2>/dev/null || echo unavailable)"
  echo "fds_now: $(find /proc/[0-9]*/fd -maxdepth 1 -type l 2>/dev/null | wc -l)"
  echo "memory_peak_kb: $(( $(cat /sys/fs/cgroup/memory.peak 2>/dev/null || echo 0) / 1024 ))"
BASH

ProbeContext = Struct.new(:http, :clock) do
  def docker
    @docker ||= DockerDaemon.new(self)
  end
end

def manifests
  @manifests ||= JSON.parse(File.read(MANIFESTS)).fetch('manifests')
end

# The tgz a test-run sends in, built from the start-point's own files.
def kata_tgz(manifest)
  files = Sandbox.in(manifest.fetch('visible_files').transform_values { |file| file['content'] })
  TGZ.of(files.merge(home_files(Sandbox::DIR, 50 * 1024)))
end

def measure(context, display_name)
  manifest = manifests[display_name]
  return puts("#{display_name}: not in the fixture") if manifest.nil?

  image_name = manifest.fetch('image_name')
  config = CyberDojoShContainerConfig.image_config(image_name)
  code, body = context.docker.create_container(config)
  if code == 404
    # A node this probe has not run on before holds few of the language images,
    # and a create is the only call that says which. Pulling here rather than
    # beforehand keeps the probe to the images it is asked for.
    context.docker.pull_image(image_name)
    code, body = context.docker.create_container(config)
  end
  return puts("#{display_name}: create answered #{code}: #{body}") unless code.between?(200, 299)

  container_id = JSON.parse(body)['Id']
  context.docker.start_container(container_id)

  # The kata goes in through an exec, as a test-run does on this branch, with
  # the measuring appended to the command rather than tarred out by a trap.
  exec_config = CyberDojoShContainerConfig.exec_config(ID)
                                          .merge('Cmd' => ['bash', '-c', "tar -C / -zxf - && #{MEASURE}"])
  code, body = context.docker.create_exec(container_id, exec_config)
  return puts("#{display_name}: exec create answered #{code}: #{body}") unless code.between?(200, 299)

  stream = context.docker.start_exec(JSON.parse(body)['Id'])
  stream.write(kata_tgz(manifest))
  stream.close_write
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_SECONDS
  reader = DeadlineReader.new(stream, deadline)
  stdout, stderr = DockerAttachFrames.demultiplex(reader)

  puts "#{display_name}  #{image_name}"
  puts stdout
  puts "stderr: #{stderr}" unless stderr.empty?
  puts
  context.docker.remove_container(container_id)
rescue DeadlineReader::Expired
  puts "#{display_name}: no answer inside #{MAX_SECONDS} seconds"
  context.docker.stop_container(container_id, seconds: 1)
end

context = ProbeContext.new(DockerSocket.new, MonotonicClock.new)
display_names =
  case ARGV
  in [] then SAMPLE
  in ['all'] then manifests.keys.sort
  else ARGV
  end
display_names.each { |display_name| measure(context, display_name) }
