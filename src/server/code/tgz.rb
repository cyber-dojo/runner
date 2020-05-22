# frozen_string_literal: true
require_relative 'gnu_unzip'
require_relative 'gnu_zip'
require_relative 'tarfile_reader'
require_relative 'tarfile_writer'

module TGZ

  def self.of(files)
    Gnu.zip(TarFile::Writer.new(files).tar_file)
  end

  def self.files(tgz)
    reader = TarFile::Reader.new(Gnu.unzip(tgz))
    reader.files.each.with_object({}) do |(filename,content),memo|
      memo[filename] = content
    end
  end

end
