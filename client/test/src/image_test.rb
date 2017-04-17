require_relative 'test_base'

class ImageTest < TestBase

  def self.hex_prefix; '4CD0A7F'; end

  # - - - - - - - - - - - - - - - - - - - - -
  # pull
  # - - - - - - - - - - - - - - - - - - - - -

  test 'B21',
  'false when image_name is valid but does not exist' do
    refute image_pull("#{cdf}/lazybox")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'B22',
  'true when image_name is valid and exists' do
    assert image_pull("#{cdf}/gcc_assert")
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'B23',
  'raises when image_name is invalid_image' do
    error = assert_raises(StandardError) {
      image_pull INVALID_IMAGE_NAME
    }
    assert error.message.start_with? 'RunnerService:image_pull:'
  end

  # - - - - - - - - - - - - - - - - - - - - -
  # pulled?
  # - - - - - - - - - - - - - - - - - - - - -

  test 'EF4',
  'false when image_name is valid but unpulled' do
    refute image_pulled?('lazybox')
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'EF5',
  'true when image_name is valid and pulled' do
    image_pull VALID_IMAGE_NAME
    assert image_pulled?(VALID_IMAGE_NAME)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'EF6',
  'false when image_name is invalid' do
    refute image_pulled?(INVALID_IMAGE_NAME)
  end

end
