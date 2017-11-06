require_relative 'test_base'

class AvatarTest < TestBase

  def self.hex_prefix
    '4F725'
  end

  test 'D08', %w( avatar_new is a no-op for API compatibility ) do
    avatar_new
  end

  test 'D09', %w( avatar_old is a no-op for API compatibility ) do
    avatar_old
  end

end
