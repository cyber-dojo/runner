# frozen_string_literal: true
require_relative 'test_base'
require_source 'tarfile_reader'
require_source 'tarfile_writer'

class TarFileTest < TestBase

  def self.id58_prefix
    '80B'
  end

  # - - - - - - - - - - - - - - - - - -

  test '364', 'simple tar round-trip' do
    writer = TarFile::Writer.new
    expected = {
      'hello.txt' => 'greetings earthlings...',
      'hiker.c' => '#include <stdio.h>'
    }
    expected.each do |filename, content|
      writer.write(filename, content)
    end
    reader = TarFile::Reader.new(writer.tar_file)
    actual = reader.files
    assert_equal expected, actual
  end

  # - - - - - - - - - - - - - - - - - -

  test '365', 'writing content where .size != .bytesize does not throw' do
    utf8 = [226].pack('U*')
    refute_equal utf8.size, utf8.bytesize
    TarFile::Writer.new.write('hello.txt', utf8)
    assert doesnt_throw=true
  end

  # - - - - - - - - - - - - - - - - - -

  test '366', 'empty file round-trip' do
    writer = TarFile::Writer.new
    filename = 'greeting.txt'
    writer.write(filename, '')
    read = TarFile::Reader.new(writer.tar_file).files[filename]
    assert_equal '', read
  end

end
