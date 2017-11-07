require_relative 'test_base'

class AvatarTest < TestBase

  def self.hex_prefix
    '20A7A'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '75F', %w( avatar_new and avatar_old are no-ops for API compatibility ) do
    in_kata {
      avatar_new
      avatar_old
    }
  end

end
