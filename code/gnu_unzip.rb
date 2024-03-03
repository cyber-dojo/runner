# frozen_string_literal: true
require 'stringio'
require 'zlib'

module Gnu
  def self.unzip(str)
    reader = Zlib::GzipReader.new(StringIO.new(str))
    unzipped = reader.read
    reader.close
    unzipped
  end
end
