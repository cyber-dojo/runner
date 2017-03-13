require_relative 'test_base'

class PulledTest < TestBase

  def self.hex_prefix; 'F33A09'; end

  test '5EC',
  'image_pulled?(valid but unpulled image_name) is false' do
    assert_equal false, image_pulled?('lazybox')
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'B22',
  'image_pulled?(valid and pulled image_name) is true' do
    image_pull VALID_IMAGE_NAME
    assert_equal true, image_pulled?(VALID_IMAGE_NAME)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'D71',
  'image_pulled?(invalid_image name) raises' do
    error = assert_raises(StandardError) {
      image_pulled? INVALID_IMAGE_NAME
    }
    expected = 'RunnerService:image_pulled?:image_name:invalid'
    assert_equal expected, error.message
  end

end
