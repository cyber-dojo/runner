# frozen_string_literal: true

# Measures how much of a container's startup a pool could take off the press.
#
# time_docker_run_split.sh splits docker run into create at about 16ms and
# start at about 48ms, which says a pool of pre-created but never-started
# containers recovers only the smaller half. It does not say what a pool of
# pre-started containers recovers, because a started container's stdin is
# already closed and the payload has to arrive another way.
#
# So three variants are timed, each from the instant of the press to the
# instant the whole payload has been read back, which is what the learner
# waits for:
#
#   cold    docker run, as runner.rb does it now
#   created docker create off the clock, press is docker start --attach
#   started container already running and idle, press is docker exec -i
#
# The work inside is identical and trivial in all three, so the differences
# are container lifecycle rather than the kata.
#
# Run on the host:
#
#   ruby docs/profiling/time_press_with_cold_created_started_container.rb
#
# Not inside the runner image on a developer machine whose architecture differs
# from it. Each variant spawns a docker CLI, and emulating that process inflates
# every row: the pre-started press reads 114.3ms emulated against 32.2ms here.

require_relative '../../source/server/tgz'

IMAGE = ARGV[0] || 'ghcr.io/cyber-dojo-languages/perl_test_simple:dc0f44a'
RUNS = 10

UID = 41_966
GID = 51_966

# The flag set from docker_run_cyber_dojo_sh_command in runner.rb, minus --rm,
# because every variant here removes its container as a separate step.
FLAGS = [
  '--init',
  '--interactive',
  "--user=#{UID}:#{GID}",
  "--tmpfs /sandbox:exec,size=250M,uid=#{UID},gid=#{GID}",
  '--tmpfs /tmp:exec,size=250M,mode=1777',
  '--ulimit core=0 --ulimit fsize=268435456 --ulimit locks=1024',
  '--ulimit nofile=1024 --ulimit nproc=1024 --ulimit stack=16777216',
  '--ulimit data=4294967296',
  '--memory=2g --net=none --pids-limit=128 --security-opt=no-new-privileges'
].join(' ')

# What the container does with the press: take the files on stdin and send a
# payload back, which is the shape of cyber_dojo_main.sh without the kata.
BODY = 'tar -C /tmp -zxf - && dd if=/dev/zero bs=1024 count=64 status=none | gzip -1'

# The files a press delivers, sized like a small kata's.
PAYLOAD_IN = TGZ.of({
                      'tmp/hiker.pl' => "sub answer {\n  return 6 * 9;\n}\n\n1;\n",
                      'tmp/hiker.t' => "use Test::Simple tests => 1;\nok(answer() == 42);\n",
                      'tmp/cyber-dojo.sh' => "perl hiker.t\n"
                    })

# Returns monotonic seconds.
def now
  Process.clock_gettime(Process::CLOCK_MONOTONIC)
end

# Runs a command, writes the press payload to its stdin, reads its stdout to
# EOF, and returns the seconds that took. This is what capture3_with_timeout.rb
# does, reduced to what is being compared.
def press(command)
  in_read, in_write = IO.pipe
  out_read, out_write = IO.pipe
  in_write.binmode
  out_read.binmode

  t0 = now
  pid = Process.spawn(command, pgroup: true, in: in_read, out: out_write, err: File::NULL)
  waiter = Process.detach(pid)
  in_read.close
  out_write.close
  in_write.write(PAYLOAD_IN)
  in_write.close
  out_read.read
  waiter.value
  t1 = now

  out_read.close
  t1 - t0
end

# Runs a docker command whose output is not being measured.
def quietly(command)
  system(command, out: File::NULL, err: File::NULL)
end

# Times a press against a container created fresh by the press itself.
def time_cold(name)
  seconds = press("docker run #{FLAGS} --name #{name} --entrypoint='' #{IMAGE} bash -c \"#{BODY}\"")
  quietly("docker rm --force #{name}")
  seconds
end

# Times a press against a container created before the clock started.
def time_created(name)
  quietly("docker create #{FLAGS} --name #{name} --entrypoint='' #{IMAGE} bash -c \"#{BODY}\"")
  seconds = press("docker start --attach --interactive #{name}")
  quietly("docker rm --force #{name}")
  seconds
end

# Times a press against a container already running and idle, where the press
# is a docker exec because a started container's stdin is already closed.
def time_started(name)
  quietly("docker run --detach #{FLAGS} --name #{name} --entrypoint='' #{IMAGE} sleep 300")
  seconds = press("docker exec --interactive #{name} bash -c \"#{BODY}\"")
  quietly("docker rm --force #{name}")
  seconds
end

# Returns the mean of an array of seconds, in milliseconds, to one decimal.
def mean_millis(values)
  format('%.1f', (values.sum / values.size) * 1000)
end

cold = []
created = []
started = []

RUNS.times do |i|
  cold << time_cold("probe_press_cold_#{i}_#{Process.pid}")
  created << time_created("probe_press_created_#{i}_#{Process.pid}")
  started << time_started("probe_press_started_#{i}_#{Process.pid}")
end

puts "image: #{IMAGE}"
puts(format('%-40s %10s', 'press', 'ms'))
puts(format('%-40s %10s', 'cold: docker run', mean_millis(cold)))
puts(format('%-40s %10s', 'pre-created: docker start --attach', mean_millis(created)))
puts(format('%-40s %10s', 'pre-started: docker exec -i', mean_millis(started)))
