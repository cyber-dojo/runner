require_relative 'test_base'

class RunTest < TestBase

  def self.hex_prefix; '58410'; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '1DC',
  'run with invalid image_name raises' do
    error = assert_raises(ArgumentError) {
      sss_run({ image_name:INVALID_IMAGE_NAME })
    }
    assert_equal 'image_name:invalid', error.message
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'C2E',
  'run with valid image_name does not raise' do
    sss_run({ image_name:VALID_IMAGE_NAME })
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  INVALID_IMAGE_NAME = '_cantStartWithSeparator'
  VALID_IMAGE_NAME = 'busybox'

end
