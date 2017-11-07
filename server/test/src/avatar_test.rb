require_relative 'test_base'

class AvatarTest < TestBase

  def self.hex_prefix
    '20A7A'
  end

  def hex_setup
    set_image_name 'cyberdojofoundation/gcc_assert'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '75E', %w( avatar_new is a no-op for API compatibility ) do
    in_kata {
      avatar_new
    }
  end

  test '75F', %w( avatar_old is a no-op for API compatibility ) do
    in_kata {
      avatar_old
    }
  end

end
