# frozen_string_literal: true
require_relative 'gnu_unzip'
require_relative 'gnu_zip'
require_relative 'tar_reader'
require_relative 'tar_writer'

module TGZ

  def self.of(files)
    Gnu.zip(Tar::Writer.new(files).tar_file)
  end

  def self.files(tgz)
    reader = Tar::Reader.new(Gnu.unzip(tgz))
    reader.files.each_with_object({}) do |(filename,content),memo|
      memo[filename] = content
    end
  end

end
