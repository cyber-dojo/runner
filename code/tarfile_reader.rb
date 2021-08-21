require 'rubygems/package'  # Gem::Package::TarReader
require 'stringio'

module TarFile

  class Reader

    def initialize(tar_file)
      io = StringIO.new(tar_file, 'r+t')
      @reader = Gem::Package::TarReader.new(io)
    end

    def files
      @reader.each.with_object({}) do |entry,memo|
        filename = entry.full_name
        content = entry.read || '' # avoid nil
        memo[filename] = content
      end
    end

  end

end
