require_relative 'test_base'

class KataTest < TestBase

  def self.hex_prefix; '137D09A'; end

  test '4EA',
  'kata_new is a no-op' do
    assert_equal({}, kata_new(VALID_IMAGE_NAME, VALID_KATA_ID))
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '78D',
  'kata_old is a no-op' do
    assert_equal({}, kata_old(VALID_IMAGE_NAME, VALID_KATA_ID))
  end

end
