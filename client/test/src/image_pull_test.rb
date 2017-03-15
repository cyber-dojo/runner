require_relative 'test_base'

class ImagePullTest < TestBase

  def self.hex_prefix; '4CD0A7F'; end

  test '5EC',
  'false when image_name is valid but does not exist' do
    assert_equal false, image_pull('lazybox')
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'B22',
  'true when image_name is valid and exists' do
    assert_equal true, image_pull("#{cdf}/gcc_assert")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'D71',
  'raises when image_name is invalid_image' do
    error = assert_raises(StandardError) {
      image_pull INVALID_IMAGE_NAME
    }
    expected = 'RunnerService:image_pull:image_name:invalid'
    assert_equal expected, error.message
  end

end
