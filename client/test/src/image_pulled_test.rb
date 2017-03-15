require_relative 'test_base'

class ImagePulledTest < TestBase

  def self.hex_prefix; 'F33A09'; end

  test 'B22',
  'raises when image_name is invalid' do
    error = assert_raises(StandardError) {
      image_pulled? INVALID_IMAGE_NAME
    }
    expected = 'RunnerService:image_pulled?:image_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '2CD',
  'false when image_name is valid but unpulled' do
    assert_equal false, image_pulled?('lazybox')
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'DB2',
  'true when image_name is valid and pulled' do
    image_pull VALID_IMAGE_NAME
    assert_equal true, image_pulled?(VALID_IMAGE_NAME)
  end

end
