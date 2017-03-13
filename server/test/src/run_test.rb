require_relative 'test_base'

class RunTest < TestBase

  def self.hex_prefix; '58410'; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'C2E',
  'valid image_name does not raise' do
    sss_run({ image_name:VALID_IMAGE_NAME })
  end

  test 'FAE',
  'valid avatar_name does not raise' do
    sss_run({ avatar_name:'salmon' })
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '1DC',
  'invalid image_name raises' do
    error = assert_raises(ArgumentError) {
      sss_run({ image_name:INVALID_IMAGE_NAME })
    }
    assert_equal 'image_name:invalid', error.message
  end

  test 'C3A',
  'invalid avatar_name raises' do
    error = assert_raises(ArgumentError) {
      sss_run({ avatar_name:'polaroid' })
    }
    assert_equal 'avatar_name:invalid', error.message
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  INVALID_IMAGE_NAME = '_cantStartWithSeparator'
  VALID_IMAGE_NAME = 'busybox'

end
