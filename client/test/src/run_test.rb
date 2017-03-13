require_relative 'test_base'

class RunTest < TestBase

  def self.hex_prefix; 'EF4356'; end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'D71',
  'invalid image_name raises' do
    error = assert_raises(StandardError) {
      sss_run({image_name:INVALID_IMAGE_NAME})
    }
    expected = 'RunnerService:run:image_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'A29',
  'invalid avatar_name raises' do
    error = assert_raises(StandardError) {
      sss_run({avatar_name:INVALID_AVATAR_NAME})
    }
    expected = 'RunnerService:run:avatar_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3DF',
  'valid image_name and valid avatar_name does not raise' do
    sss_run({image_name:VALID_IMAGE_NAME, avatar_name:VALID_AVATAR_NAME})
    assert_stdout ''
    assert_stderr ''
    assert_status 0
  end

end
