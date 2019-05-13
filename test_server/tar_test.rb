require_relative 'test_base'
require_relative '../src/tar_reader'
require_relative '../src/tar_writer'

class TarTest < TestBase

  def self.hex_prefix
    '80B'
  end

  test '364', 'simple tar round-trip' do
    writer = TarWriter.new
    expected = {
      'hello.txt' => 'greetings earthlings...',
      'hiker.c' => '#include <stdio.h>'
    }
    expected.each do |filename, content|
      writer.write(filename, content)
    end
    reader = TarReader.new(writer.tar_file)
    actual = reader.files
    assert_equal expected, actual
  end

end
