require 'rubygems/package'  # Gem::Package::TarWriter
require 'stringio'

module Tar

  class Writer

    def initialize
      @tar_file = StringIO.new('')
      @writer = Gem::Package::TarWriter.new(@tar_file)
      if block_given?
        yield self
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
