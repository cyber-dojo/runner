require_relative 'test_base'

class LargeFileTruncationTest < TestBase

  def self.hex_prefix
    'E4A'
  end

  # - - - - - - - - - - - - - - - - -

  test '52A',
  %w( generated text files bigger than 50K are truncated ) do
    filename = 'large_file.txt'
    script = "od -An -x /dev/urandom | head -c#{51*1024} > #{filename}"
    script += ";stat -c%s #{filename}"
    all_OSes.each do |os|
      @os = os
      assert_cyber_dojo_sh(script)
      assert_stdout "#{51*1024}\n"
      assert created[filename]['truncated']
      assert_equal 50*1024, created[filename]['content'].size
      assert_deleted([])
      assert_changed({})
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '52B',
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
