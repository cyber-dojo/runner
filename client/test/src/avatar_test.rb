require_relative 'test_base'

class AvatarTest < TestBase

  def self.hex_prefix; '981F06E'; end

  test 'B65',
  'avatar_new is a no-op' do
    assert_equal({}, avatar_new(
      VALID_IMAGE_NAME, VALID_KATA_ID, VALID_AVATAR_NAME, {})
    )
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '70D',
  'avatar_old is a no-op' do
    assert_equal({}, avatar_old(
      VALID_IMAGE_NAME, VALID_KATA_ID, VALID_AVATAR_NAME)
    )
  end

end
