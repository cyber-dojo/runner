require 'zlib'

# https://gist.github.com/sinisterchipmunk/1335041

def gzip(s)
  zipped = StringIO.new('')
  writer = Zlib::GzipWriter.new(zipped)
  writer.write(s)
  writer.close
  zipped.string
end
