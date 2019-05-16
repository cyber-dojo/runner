require 'zlib'

# https://gist.github.com/sinisterchipmunk/1335041

def ungzip(s)
  reader = Zlib::GzipReader.new(StringIO.new(s))
  unzipped = StringIO.new(reader.read)
  reader.close
  unzipped.string
end
