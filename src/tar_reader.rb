require 'rubygems/package'  # Gem::Package::TarReader
require 'stringio'

class TarReader

  def initialize(tar_file)
    io = StringIO.new(tar_file, 'r+t')
    @reader = Gem::Package::TarReader.new(io)
  end

  def files
    Hash[@reader.map { |e| [e.full_name, e.read] }]
  end

end
