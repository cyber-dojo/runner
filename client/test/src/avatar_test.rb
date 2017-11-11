require_relative 'test_base'

class AvatarTest < TestBase

  def self.hex_prefix
    '4F725'
  end

  multi_os_test 'D08',
  %w( avatar_new/avatar_old are no-ops for API compatibility ) do
    avatar_new
    avatar_old
  end

end
