require 'stringio'
require 'zlib'

module Gnu

  module_function

  def unzip(s)
    reader = Zlib::GzipReader.new(StringIO.new(s))
    unzipped = StringIO.new(reader.read)
    reader.close
    unzipped.string
  end

end

# https://gist.github.com/sinisterchipmunk/1335041
