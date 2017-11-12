require_relative 'test_base'

class NoOpTest < TestBase

  def self.hex_prefix
    '4F725'
  end

  multi_os_test 'D87',
  %w( kata_new/kata_old are no-ops for API compatibility ) do
    kata_new
    kata_old
  end

  multi_os_test 'D08',
  %w( avatar_new/avatar_old are no-ops for API compatibility ) do
    avatar_new
    avatar_old
  end

end
