require_relative 'test_base'

class AvatarNewOldTest < TestBase

  def self.hex_prefix
    'DC162'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '751', %w( resurrection requires avatar_new to work after avatar_old ) do
    in_kata {
      avatar_new('squid')
      avatar_old('squid')
      avatar_new('squid')
      avatar_old('squid')
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '752', %w( avatar_new is idempotent because the runner is stateless ) do
    in_kata_as('squid') {
      avatar_new('squid')
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '753', %w( avatar_old is idempotent because the runner is stateless ) do
    in_kata {
      avatar_new('squid')
      avatar_old('squid')
      avatar_old('squid')
    }
  end

end
