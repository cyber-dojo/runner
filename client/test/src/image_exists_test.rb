require_relative 'test_base'

class ImageExistsTest < TestBase

  def self.hex_prefix; 'FFEE45'; end

  test '17F',
  'false when image_name is valid but does not exist' do
    assert_equal false, image_exists?("#{cdf}/lazybox")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'AA1',
  'true when image_name is valid and exists' do
    assert_equal true, image_exists?("#{cdf}/gcc_assert")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'D6F',
  'raises when image_name is invalid' do
    error = assert_raises(StandardError) {
      image_exists? INVALID_IMAGE_NAME
    }
    expected = 'RunnerService:image_exists?:image_name:invalid'
    assert_equal expected, error.message
  end

end
