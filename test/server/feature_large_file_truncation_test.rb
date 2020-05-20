# frozen_string_literal: true
require_relative 'test_base'

class LargeFileTruncationTest < TestBase

  def self.id58_prefix
    'E4A'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '52A',
  %w( generated text files bigger than 50K are truncated ) do
    filename = 'large_file.txt'
    script = "od -An -x /dev/urandom | head -c#{51*1024} > #{filename}"
    script += ";stat -c%s #{filename}"
    assert_cyber_dojo_sh(script)
    assert_equal "#{51*1024}\n", stdout, :stdout
    assert created[filename]['truncated'], :truncated
    assert_equal 50*1024, created[filename]['content'].size, :size
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  test '52B',
  %w( source files bigger than 10K are not truncated ) do
    filename = 'Hiker.cs'
    src = starting_files[filename]
    large_comment = "/*#{'x'*10*1024}*/"
    refute_nil src
    run_cyber_dojo_sh( {
      changed:{
        filename => src + large_comment
      }
    })
    refute changed.keys.include?(filename)
  end

end
