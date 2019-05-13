require 'rubygems/package'  # Gem::Package::TarReader
require 'stringio'

class TarReader

  def initialize(tar_file)
    @reader = Gem::Package::TarReader.new(StringIO.new(tar_file, 'r+t'))
  end

  def files
    Hash[@reader.map { |entry| [entry.full_name, entry.read] }]
  end

end
