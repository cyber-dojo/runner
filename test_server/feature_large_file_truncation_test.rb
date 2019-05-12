require_relative 'test_base'

class LargeFileTruncationTest < TestBase

  def self.hex_prefix
    'E4A'
  end

  # - - - - - - - - - - - - - - - - -

  test '62A',
  %w( generated files bigger than 25K are truncated ) do
    s = '123456789A' + 'BCDEFGHIJK' + '1234'
    script = "yes '#{s}' | head -n 1025 > large_file.txt"
    all_OSes.each do |os|
      @os = os
      assert_cyber_dojo_sh(script)
      expected = "#{s}\n" * 1024

      assert_created({ 'large_file.txt' => truncated(expected) })
      assert_deleted([])
      assert_changed({})
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '62B',
  %w( source files bigger than 10K are not truncated ) do
    filename = 'Hiker.cs'
    src = starting_files[filename]['content']
    large_comment = "/*#{'x'*10*1024}*/"
    refute_nil src
    run_cyber_dojo_sh( {
      changed:{
        filename => intact(src + large_comment)
      }
    })
    refute changed.keys.include?(filename)
  end

end
