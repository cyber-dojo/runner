# frozen_string_literal: true
require_relative 'gnu_unzip'
require_relative 'gnu_zip'
require_relative 'tarfile_reader'
require_relative 'tarfile_writer'

module TGZ
  def self.of(files)
    writer = TarFile::Writer.new
    files.each do |filename, content|
      writer.write(filename, content)
    end
    Gnu.zip(writer.tar_file)
  end

  def self.files(tgz)
    unzipped = Gnu.unzip(tgz)
    reader = TarFile::Reader.new(unzipped)
    reader.files.each.with_object({}) do |(filename, content), memo|
      memo[filename] = content
    end
  end
end
