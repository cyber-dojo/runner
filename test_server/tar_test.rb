require_relative 'test_base'
require_relative '../src/tar_reader'
require_relative '../src/tar_writer'

class TarTest < TestBase

  def self.hex_prefix
    '80B'
  end

  # - - - - - - - - - - - - - - - - - -

  test '364', 'simple tar round-trip' do
    writer = Tar::Writer.new
    expected = {
      'hello.txt' => 'greetings earthlings...',
      'hiker.c' => '#include <stdio.h>'
    }
    expected.each do |filename, content|
      writer.write(filename, content)
    end
    reader = Tar::Reader.new(writer.tar_file)
    actual = reader.files
    assert_equal expected, actual
  end

  # - - - - - - - - - - - - - - - - - -

  test '365', 'writing content where .size != .bytesize does not throw' do
    utf8 = [226].pack('U*')
    refute_equal utf8.size, utf8.bytesize
    Tar::Writer.new.write('hello.txt', utf8)
    assert doesnt_throw=true
  end

  # - - - - - - - - - - - - - - - - - -

  test '366', 'empty file round-trip' do
    writer = Tar::Writer.new
    filename = 'greeting.txt'
    writer.write(filename, '')
    read = Tar::Reader.new(writer.tar_file).files[filename]
    assert_equal '', read
  end

end
