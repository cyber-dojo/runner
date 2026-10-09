# frozen_string_literal: true

# Parses runner payloads and reports the time taken and the peak RSS together,
# so a ruby VM knob can be priced on both axes from one process. The two have
# to come from the same run: a knob that buys speed by holding more memory is
# only worth having if the memory is there, and a container's mem_limit is
# checked against RSS.
#
# The work is TGZ.files, which is what runner.rb calls to turn a container's
# payload into files. Driving real runner code rather than an allocation loop
# keeps the allocation mix the one production sees, which is the whole point
# when the knob under test is an allocator.
#
# Run by compare_yjit_against_interpreter.sh and by
# compare_jemalloc_against_musl_malloc.sh, which supply the payloads, the ruby,
# and the knob. The thread count is an argument because the two questions want
# different answers from it: YJIT is about interpreter speed and is legible on
# one thread, while an allocator's behaviour on one thread is not its behaviour
# under several.
#
# Usage: ruby measure_parse_time_and_rss.rb THREADS PAYLOAD.tar...

require '/repo/source/server/lib/tgz'

RUNS_PER_THREAD = 20

# Returns the process's peak resident set size in KB. VmHWM is a high-water
# mark, so it still reports the peak after a GC has handed the pages back,
# which is what the OOM killer would have seen.
def peak_rss_kb
  File.readlines('/proc/self/status')
      .grep(/\AVmHWM:/)
      .first
      .split[1]
      .to_i
end

# Returns a label naming the two knobs this process is running under, so each
# row says which configuration produced it rather than depending on the
# caller printing the rows in the order it thinks it asked for.
def ruby_label
  yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? 'yjit' : 'interp'
  malloc = ENV['LD_PRELOAD'].to_s.include?('jemalloc') ? 'jemalloc' : 'libc'
  tuning = ENV['MALLOC_CONF'].to_s
  "#{yjit}/#{malloc}#{tuning.empty? ? '' : " #{tuning}"}"
end

# Parses once per thread without timing it, so that what follows is measured
# in steady state. Without this the first payload in the list absorbs the
# whole of YJIT's compilation and reports as ten times slower than the
# interpreter, which says nothing about the long-lived puma worker this is
# asking about.
def warm_up(tgz, threads)
  Array.new(threads) { Thread.new { TGZ.files(tgz) } }.each(&:join)
end

# Returns the mean microseconds of one TGZ.files call, with the parses spread
# over the given number of threads. The mean is per parse, not per thread, so
# rows taken at different thread counts are comparable.
def mean_parse_micros(tgz, threads)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  Array.new(threads) {
    Thread.new { RUNS_PER_THREAD.times { TGZ.files(tgz) } }
  }.each(&:join)
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ((t1 - t0) * 1_000_000 / (RUNS_PER_THREAD * threads)).round
end

# Prints one table row, the first cell left aligned and the rest right aligned.
def print_row(cells)
  head, *tail = cells
  puts(head.to_s.ljust(10) + tail.map { |cell| cell.to_s.rjust(12) }.join)
end

# Prints one row per payload, having gzipped it the way a container would.
def measure(paths, threads)
  paths.each do |path|
    tgz = Gnu.zip(File.binread(path))
    warm_up(tgz, threads)
    print_row([File.basename(path, '.tar'), File.size(path),
               mean_parse_micros(tgz, threads), peak_rss_kb])
  end
end

threads = Integer(ARGV.first)
puts "ruby:    #{ruby_label}"
puts "threads: #{threads}"
print_row(['profile', 'tar bytes', 'parse us', 'peak RSS KB'])
measure(ARGV.drop(1), threads)
