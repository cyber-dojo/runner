require_relative 'test_base'
require_relative '../src/shell_assert_error'

class ShellAssertErrorTest < TestBase

  def self.hex_prefix
    'D0F'
  end

  # - - - - - - - - - - - - - - - - - - -

  BAD_UTF8 = "\255"

  test '1CA', %w( check illegal/malformed utf8 test data ) do
    error = assert_raises(ArgumentError) { BAD_UTF8.split }
    assert_equal 'invalid byte sequence in UTF-8', error.message
  end

  # - - - - - - - - - - - - - - - - - - -

  test '1CB',
  %w( bad-utf-8 in command is converted ) do
    ShellAssertError.new(BAD_UTF8,'','',0)
  end

  # - - - - - - - - - - - - - - - - - - -

  test '1CC',
  %w( bad-utf-8 in stdout is converted ) do
    ShellAssertError.new('',BAD_UTF8,'',0)
  end

  # - - - - - - - - - - - - - - - - - - -

  test '1CD',
  %w( bad-utf-8 in stderr is converted ) do
    ShellAssertError.new('','',BAD_UTF8,0)
  end

end
