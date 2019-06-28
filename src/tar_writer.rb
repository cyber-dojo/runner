require 'rubygems/package'  # Gem::Package::TarWriter
require 'stringio'

module Tar

  class Writer

    def initialize(files = {})
      @tar_file = StringIO.new('')
      @writer = Gem::Package::TarWriter.new(@tar_file)
      files.each do |filename, content|
        write(filename, content)
      end
    end

    def write(filename, content)
      size = content.bytesize
      @writer.add_file_simple(filename, 0o644, size) do |fd|
        fd.write(content)
      end
    end

    def tar_file
      @tar_file.string
    end

  end

end
