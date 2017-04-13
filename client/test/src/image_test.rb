require_relative 'test_base'

class ImageTest < TestBase

  def self.hex_prefix; '4CD0A7F'; end

  # - - - - - - - - - - - - - - - - - - - - -
  # pull
  # - - - - - - - - - - - - - - - - - - - - -

  test '5EC',
  'false when image_name is valid but does not exist' do
    assert_equal false, image_pull("#{cdf}/lazybox")
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

  # - - - - - - - - - - - - - - - - - - - - -
  # pulled?
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

  # - - - - - - - - - - - - - - - - - - - - -

  test 'EF6',
  'raises when image_name is invalid' do
    error = assert_raises(StandardError) {
      image_pulled? INVALID_IMAGE_NAME
    }
    expected = 'RunnerService:image_pulled?:image_name:invalid'
    assert_equal expected, error.message
  end

end
