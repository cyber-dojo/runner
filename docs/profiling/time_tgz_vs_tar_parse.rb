# frozen_string_literal: true

# Measures the runner half of the question "is gzip worth it?".
#
# runner.rb reaches its files through TGZ.files(tgz_out), which inflates the
# whole payload with Zlib and then walks it with Gem::Package::TarReader. Only
# the inflate is in question here, so each payload is parsed both ways and the
# difference is the price the runner pays for the container having compressed.
#
# Run by time_tgz_vs_tar_parse.sh, which supplies the payloads and a ruby whose
# architecture matches the host, since emulation would inflate exactly the CPU
# cost being measured.

require '/repo/source/server/gnu_zip'
require '/repo/source/server/tgz'
require '/repo/source/server/tarfile_reader'

RUNS = 10

# Returns the mean seconds per call of running the block RUNS times.
def mean_seconds(&block)
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  RUNS.times(&block)
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  (t1 - t0) / RUNS
end

# Returns microseconds, rounded, for a seconds duration.
def micros(seconds)
  (seconds * 1_000_000).round
end

# Prints one table row, the first cell left aligned and the rest right aligned.
def print_row(cells)
  head, *tail = cells
  puts(head.to_s.ljust(10) + tail.map { |cell| cell.to_s.rjust(12) }.join)
end

# Prints one row comparing inflate-plus-untar against untar alone.
def time_parse(name, tar)
  tgz = Gnu.zip(tar)
  tgz_us = micros(mean_seconds { TGZ.files(tgz) })
  tar_us = micros(mean_seconds { TarFile::Reader.new(tar.dup).files })
  print_row([name, tar.size, tgz.size, tar_us, tgz_us, tgz_us - tar_us])
end

# Prints the table header, naming the two parses being compared.
def print_header
  print_row(['profile', 'tar bytes', 'gz bytes', 'tar us', 'tgz us', 'gzip cost'])
end

print_header
ARGV.each do |path|
  time_parse(File.basename(path, '.tar'), File.binread(path))
end
