# frozen_string_literal: true

# Measures what it would cost a test-run to find its spare in a directory
# every worker can read, instead of in its own memory.
#
# SparePool is per worker, so a spare one worker warmed is one the next
# test-run cannot claim unless it happens to land on that worker. Production
# runs two puma workers in each of three tasks, so twelve spares sit in six
# private pools and a press finds one only when it lands on the worker that
# made it.
#
# time_ls_vs_create_vs_start.rb asked whether the daemon could be the shared
# place and answered no: at twelve tracked a listing costs 25.6ms, against the
# roughly 92ms a hit saves. That ruled out the daemon. It did not rule out
# sharing, which is what this probe is about.
#
# A directory can hold the same queue. One empty file per spare, named for the
# expiry and the container id, so a claim is a readdir and an unlink and reads
# no file at all. unlink(2) is winner-takes-all under the parent directory's
# inode lock, so the unlink is both the claim and the proof of it, and the
# loser gets ENOENT and walks on. Nothing is locked and nothing is parsed.
#
# So the question is what that readdir and unlink cost beside the 25.6ms they
# replace, whether the cost grows with how many spares the directory holds,
# and whether it changes on a filesystem that journals. The last matters
# because the runner's /tmp is a tmpfs under docker-compose but, with no tmpfs
# declared in deployment/terraform-runner/deployment.tf, is the container's
# writable layer in production: overlayfs above the host's disk.
#
#   claim     readdir, walk in expiry order, unlink the first usable entry
#   add       what the warm thread pays to put one in
#   race      N processes claiming from one directory at once
#
# What it found, in a linux container on aarch64 under Docker Desktop, five
# runs of 200 claims at each level, reported as the median run:
#
#   held     tmpfs claim ms    overlay claim ms
#      1             0.0038              0.0068
#      2             0.0038              0.0069
#     12             0.0062              0.0095
#     32             0.0110              0.0149
#
# An add costs 0.0031ms on the tmpfs and 0.0154ms on the overlay, and is paid
# by the warm thread rather than by a test-run.
#
# So the answer is yes, by three orders of magnitude. Twelve is what the whole
# node holds today, and a claim walking twelve costs 0.0062ms against the
# 25.6ms the same question costs the daemon: about four thousand times less,
# and about one part in fifteen thousand of the 92ms a hit saves. Thirty-two
# costs 0.0110ms, so nothing here grows into a reason to cap the directory.
#
# The journalling column is the one that could have sunk it and does not.
# Production's store is the container's writable layer unless a tmpfs is
# declared for it, and overlayfs is about 1.5 times the tmpfs: 0.0095ms
# against 0.0062ms at twelve. Both are noise beside a test-run, so the store
# does not need a tmpfs to be fast. If one is chosen anyway it is for the
# reboot it does not survive, not for the microseconds.
#
# unlink(2) is the lock, and that is what the race column measures. Eight
# processes going for one spare answered one winner in all five runs, on both
# filesystems, ten trials in all. A second winner would mean two test-runs
# handed one container, so it is the number here that is about correctness
# rather than speed.
#
# Run it inside a linux container, because the two filesystems it compares do
# not exist on a mac host, and because production's is overlayfs:
#
#   docker run --rm --volume "${PWD}/docs:/docs:ro" ruby:3.4-alpine \
#     ruby /docs/profiling/time_claim_from_a_shared_directory.rb /tmp /root
#
# The first directory should be a tmpfs and the second on the image's writable
# layer. It takes any number of directories and reports each one.

require 'fileutils'

RUNS = 200
HELD = [1, 2, 12, 32].freeze
RACERS = 8
# Every spare sleeps the same length, so made-order is expiry-order. The
# figures only have to differ and sort, so they start here and count up.
FIRST_EXPIRY_MS = 1_000_000_000

# One spare's filename. The expiry is zero-padded to a fixed width so that
# sorting the directory lexically sorts it by expiry, which is what lets a
# claim take the spare nearest its expiry without parsing anything.
def entry_name(expiry_ms, container_id)
  format('%015d-%s', expiry_ms, container_id)
end

# Fills dir with that many spares and answers nothing. Named so that the
# oldest sorts first, as a queue filled by successive warms would be.
def fill(dir, held)
  FileUtils.rm_rf(dir)
  FileUtils.mkdir_p(dir)
  held.times do |n|
    name = entry_name(FIRST_EXPIRY_MS + n, format('%012x', n))
    File.write(File.join(dir, name), '')
  end
end

# Takes the first spare in expiry order, answering its container id, or nil
# when the directory holds none. The unlink is the claim: of several processes
# unlinking one name exactly one succeeds, and the rest get ENOENT and walk
# on, so nothing here is locked.
#
# A real claim also drops an entry whose expiry is too near to serve a whole
# run, which is the same unlink against the same directory, so timing the
# claim of a usable spare times that too.
def claim(dir)
  Dir.children(dir).sort.each do |name|
    File.unlink(File.join(dir, name))
    return name.split('-').last
  rescue Errno::ENOENT
    next
  end
  nil
rescue SystemCallError
  nil
end

# Milliseconds for one claim, averaged over RUNS, refilling between each so
# that every claim walks a directory holding the same number of spares.
def time_claim(dir, held)
  total = 0.0
  RUNS.times do
    fill(dir, held)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    claimed = claim(dir)
    total += Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    raise "claimed nothing from #{held} in #{dir}" if claimed.nil?
  end
  (total / RUNS) * 1000
end

# Milliseconds for one add, which is what the warm thread pays rather than the
# test-run, so it is reported to size the warm and not the claim.
def time_add(dir)
  fill(dir, 0)
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  RUNS.times do |n|
    name = entry_name(FIRST_EXPIRY_MS + n, format('%012x', n))
    File.write(File.join(dir, name), '')
  end
  took = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  (took / RUNS) * 1000
end

# How many of RACERS processes claimed a spare when all of them went for one
# directory holding exactly one. Anything but 1 means the unlink is not the
# lock this design takes it for, so it is the number that matters most here.
#
# Each child exits 0 when it claimed and 1 when it did not, which is how the
# verdict crosses the fork. exit! rather than exit, so a child runs no at_exit
# handler belonging to the parent.
def count_winners(dir)
  fill(dir, 1)
  RACERS.times.map do
    fork do
      exit!(claim(dir).nil? ? 1 : 0)
    end
  end.count do |pid|
    _pid, status = Process.waitpid2(pid)
    status.exitstatus.zero?
  end
end

def report(dir)
  puts
  puts "#{dir} (add #{time_add(dir).round(4)}ms)"
  puts '   held    claim ms'
  HELD.each do |held|
    puts format('%7d    %8.4f', held, time_claim(dir, held))
  end
  puts "  #{RACERS} racers for 1 spare, winners: #{count_winners(dir)} (want 1)"
ensure
  FileUtils.rm_rf(dir)
end

dirs = ARGV.empty? ? ['/tmp'] : ARGV
puts "#{RUNS} runs at each level"
dirs.each { |dir| report(File.join(dir, 'claim_probe')) }
