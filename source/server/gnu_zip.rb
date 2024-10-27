require 'stringio'
require 'zlib'

module Gnu
  def self.zip(str)
    zipped = StringIO.new('')
    writer = Zlib::GzipWriter.new(zipped)
    writer.write(str)
    writer.close
    zipped.string
  end
end
