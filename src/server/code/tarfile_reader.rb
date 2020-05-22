# frozen_string_literal: true
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
        memo[entry.full_name] = entry.read || '' # avoid nil
      end
    end

  end

end
