require_relative 'test_base'

class DiskTest < TestBase

  def self.hex_prefix
    'FDF'
  end

  # - - - - - - - - - - - - - - - - -

  test 'D4C',
  'what gets written gets read back' do
    disk = Disk.new
    Dir.mktmpdir('file_writer') do |tmp_dir|
      pathed_filename = tmp_dir + '/limerick.txt'
      content = 'the boy stood on the burning deck'
      disk.write(pathed_filename, content)
      File.open(pathed_filename, 'r') { |fd| assert_equal content, fd.read }
    end
  end

end
