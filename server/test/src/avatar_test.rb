require_relative 'test_base'

class AvatarTest < TestBase

  def self.hex_prefix
    '20A7A'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '75E', %w( avatar_new is a no-op for API compatibility ) do
    avatar_new(default_avatar_name, default_visible_files)
  end

  test '75F', %w( avatar_old is a no-op for API compatibility ) do
    avatar_old(default_avatar_name)
  end

end
