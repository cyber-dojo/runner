# frozen_string_literal: true
require 'rubygems/package'  # Gem::Package::TarReader
require 'stringio'

module Tar

  class Reader

    def initialize(tar_file)
      io = StringIO.new(tar_file, 'r+t')
      @reader = Gem::Package::TarReader.new(io)
    end

    def files
      # empty files are coming back as nil
      @reader.map { |e| [e.full_name, e.read || ''] }.to_h
    end

  end

end
