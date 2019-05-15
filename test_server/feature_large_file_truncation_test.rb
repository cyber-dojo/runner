require_relative 'test_base'

class LargeFileTruncationTest < TestBase

  def self.hex_prefix
    'E4A'
  end

  # - - - - - - - - - - - - - - - - -

  test '52A',
  %w( generated text files bigger than 25K are truncated ) do
    letters = [*('a'..'z')]
    size = 25 # -1 for newline
    s = (size-1).times.map{letters[rand(letters.size)]}.join
    script = "yes '#{s}' | head -n 30001025 > large_file.txt"
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
