require 'rubygems/package'  # Gem::Package::TarWriter
require 'stringio'

class TarWriter

  def initialize
    @tar_file = StringIO.new('')
    @writer = Gem::Package::TarWriter.new(@tar_file)
  end

  def write(filename, content, mode = 0o644)
    @writer.add_file_simple(filename, mode, content.size) do |fd|
      fd.write(content)
    end
  end

  def tar_file
    @tar_file.string
  end

end
