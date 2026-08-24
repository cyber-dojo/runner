require 'stringio'
require 'zlib'

module Gnu
  # Compresses at level 1, matching send_tgz() in home_files.rb.
  #
  # The pipe to the container is local, so the smaller payload buys almost no
  # transfer time; what gzip is here for is its CRC32 and length trailer,
  # which is what makes the container's [tar -zxf -] reject a payload that
  # did not arrive intact. Level 1 costs about a third of the default level
  # and keeps most of the compression.
  # See docs/profiling/where-the-traffic-light-time-goes.txt
  def self.zip(str)
    zipped = StringIO.new
    writer = Zlib::GzipWriter.new(zipped, Zlib::BEST_SPEED)
    writer.write(str)
    writer.close
    zipped.string
  end
end
