require 'stringio'
require 'zlib'

module Gnu

  def self.zip(s)
    zipped = StringIO.new('')
    writer = Zlib::GzipWriter.new(zipped)
    writer.write(s)
    writer.close
    zipped.string
  end

end

# https://gist.github.com/sinisterchipmunk/1335041
