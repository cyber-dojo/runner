require_relative 'test_base'

class LargeFileTruncationTest < TestBase

  def self.hex_prefix
    'E4A95'
  end

  # - - - - - - - - - - - - - - - - -

  test '62A',
  %w( files bigger than 10K are truncated ) do
    script = 'yes "123456789" | head -n 1042 > large_file.txt'
    all_OSes.each do |os|
      @os = os
      in_kata { assert_cyber_dojo_sh(script) }
      expected = "123456789\n" * 1024
      expected += "\n"
      expected += 'output truncated by cyber-dojo'

      assert_equal({ 'large_file.txt' => expected }, new_files)
      assert_equal({}, deleted_files)
      assert_equal({}, changed_files)
    end
  end

end
