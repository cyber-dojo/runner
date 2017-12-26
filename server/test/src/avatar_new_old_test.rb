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

  test '752', %w( avatar_new is idempotent only if runner is stateless ) do
    if stateless?
      in_kata_as('squid') {
        avatar_new('squid')
      }
    else
      in_kata_as('squid') {
        error = assert_raises(StandardError) { avatar_new('squid') }
        assert_equal 'avatar_name:exists', error.message
      }
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '753', %w( avatar_old is idempotent only if runner is stateless ) do
    if stateless?
      in_kata {
        avatar_new('squid')
        avatar_old('squid')
        avatar_old('squid')
      }
    else
      in_kata {
        avatar_new('squid')
        avatar_old('squid')
        error = assert_raises(StandardError) { avatar_old('squid') }
        assert_equal 'avatar_name:!exists', error.message
      }
    end
  end

  private

  def stateless?
    result = nil
    in_kata_as('lion') {
      cmd = 'printenv CYBER_DOJO_RUNNER'
      result = assert_cyber_dojo_sh(cmd) == 'stateless'
    }
    result
  end

end
