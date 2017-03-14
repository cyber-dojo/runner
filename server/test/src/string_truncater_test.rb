require_relative 'test_base'
require_relative '../../src/string_truncater'

class StringTruncaterTest < TestBase

  include StringTruncater

  def self.hex_prefix; '767'; end

  test '4D1',
  'empty string is not truncated' do
    s = ''
    assert_equal s, truncated(s)
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  test '5A7',
  'string of less than 10k is not truncated' do
    s = '@' * (max_length - 1)
    assert_equal s, truncated(s)
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  test 'D8F',
  'string of exactly 10k is not truncated' do
    s = '@' * (max_length)
    assert_equal s, truncated(s)
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  test 'A48',
  'string of greater than 10k is truncated and truncated-message is appended' do
    s = '@' * (max_length)
    message = 'output truncated by cyber-dojo'
    assert_equal s + "\n" + message, truncated(s + 'x')
  end

  def max_length; 10*1024; end

end
