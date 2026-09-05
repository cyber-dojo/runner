#!/usr/bin/env ruby
# frozen_string_literal: true

# Price spawning a child process from a Ruby process, as a function of how much
# heap that process is holding.
#
# A daemonless runner execs an OCI runtime once per test-run, from a puma
# worker. dockerd does that spawning today, out of a process the runner does not
# pay for, so this cost is new. It is the only term in
# ../dropping-the-docker-daemon.md's budget with no figure at all.
#
# Heap size is the axis because it decides whether the cost is a floor or a
# tax. If MRI duplicates the worker's heap to spawn, the cost grows with the
# heap and a puma worker is the worst place to do it. If MRI uses vfork or
# posix_spawn, nothing is duplicated and the figure is flat, which makes the
# spawn a fixed cost that says the same thing wherever it is made.
#
# It found a tax, not a floor: with the collector off, 376us at 14 MB resident
# rising to 2115us at 491 MB, about 3.6us per resident MB. So the spawn
# duplicates something proportional to the parent, which is what copying page
# tables looks like, and where the spawn is made matters.
#
# The collector is not what produces that slope. Its own contribution is under
# 65us at every size above the smallest, against a rise of more than 1700us, so
# the gc-on and gc-off columns tell the same story.
#
# /bin/true is the child, so what is measured is the spawn and the wait rather
# than any work. Run it against the ruby that sinatra-base is built on:
#
#   docker run --rm --volume <repo>/runner/docs/profiling:/probe:ro \
#     ruby:4.0.5-alpine3.24 ruby /probe/time_spawn_against_ruby_heap_size.rb

RUNS = 200
CHILD = '/bin/true'

# Megabytes of heap to hold while timing. Each step is retained for the whole
# of its own timing loop, so the process really is that large when it spawns.
HEAP_STEPS_MB = [0, 50, 200, 400].freeze

# One megabyte of retained strings. Strings rather than one large buffer,
# because many small objects are what a puma worker's heap actually looks like
# and what a heap-copying spawn would have to walk.
def megabyte_of_objects
  Array.new(1024) { ' ' * 1024 }
end

# Grows ballast until it holds the given number of megabytes, and answers it so
# the caller keeps it reachable. Returning it is what stops the GC reclaiming
# the heap this probe is trying to measure against.
def ballast_of(megabytes)
  Array.new(megabytes) { megabyte_of_objects }
end

# Spawns the child once and waits for it, which is the pair a runner would do
# per test-run. Process.spawn rather than system, so no shell is involved.
def spawn_and_wait
  pid = Process.spawn(CHILD, out: File::NULL, err: File::NULL)
  Process.wait(pid)
end

# Mean microseconds of one spawn and wait, over RUNS iterations. Timed with the
# collector off as well as on, because the ballast is live objects: a GC inside
# the loop has more to scan at the larger sizes, and only the off column is the
# spawn on its own. The loop itself allocates almost nothing, so disabling the
# collector across it does not grow the heap being measured against.
def mean_spawn_us(gc_disabled:)
  GC.start
  GC.disable if gc_disabled
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  RUNS.times { spawn_and_wait }
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  GC.enable if gc_disabled
  ((t1 - t0) / RUNS * 1_000_000).round
end

# Resident size of this process in megabytes, read rather than assumed, so the
# ballast is shown to have landed rather than taken on trust.
def resident_mb
  File.read('/proc/self/status')[/VmRSS:\s+(\d+) kB/, 1].to_i / 1024
end

# Aborts before timing anything if the child cannot be spawned at all, so a
# failure is never averaged in as though it were fast.
def preflight
  spawn_and_wait
  return if $CHILD_STATUS.nil? || $?.success?

  warn "ERROR: #{CHILD} could not be spawned, so the timings are meaningless"
  exit 1
end

puts "ruby: #{RUBY_VERSION}"
puts "arch: #{RUBY_PLATFORM}"
puts

preflight

printf("%-12s %-10s %-14s %s\n", 'ballast', 'VmRSS', 'spawn+wait', 'spawn+wait')
printf("%-12s %-10s %-14s %s\n", '', '', 'gc on', 'gc off')
HEAP_STEPS_MB.each do |megabytes|
  ballast = ballast_of(megabytes)
  gc_on = mean_spawn_us(gc_disabled: false)
  gc_off = mean_spawn_us(gc_disabled: true)
  printf("%-12s %-10s %9d us %9d us\n", "#{megabytes} MB", "#{resident_mb} MB", gc_on, gc_off)
  # Held until here so the ballast is live across both timing loops above,
  # which is the whole point of allocating it.
  ballast.clear
end
