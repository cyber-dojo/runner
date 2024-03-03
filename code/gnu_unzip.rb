require 'stringio'
require 'zlib'

module Gnu
  def self.unzip(s)
    reader = Zlib::GzipReader.new(StringIO.new(s))
    unzipped = reader.read
    reader.close
    unzipped
  end
end
