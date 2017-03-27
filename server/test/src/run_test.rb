require_relative 'test_base'

class RunTest < TestBase

  def self.hex_prefix; '58410'; end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'C2E',
  '[Alpine] valid image_name,kata_id,avatar_name does not raise' do
    sss_run({
      image_name:VALID_ALPINE_IMAGE_NAME,
         kata_id:VALID_KATA_ID,
     avatar_name:VALID_AVATAR_NAME
    })
  end

  test '8A4',
  '[Ubuntu] valid image_name,kata_id,avatar_name does not raise' do
    sss_run({
      image_name:VALID_UBUNTU_IMAGE_NAME,
         kata_id:VALID_KATA_ID,
     avatar_name:VALID_AVATAR_NAME
    })
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '8A9',
  'run with image=cdf/gcc_assert returns non-nil traffic-light colour' do
    sss_run( { image_name:"#{cdf}/gcc_assert" })
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

=begin
  test '8C5',
  'run with image!=cdf/gcc_assert returns nil traffic-light colour' do
    sss_run( { image_name:"#{cdf}/clangpp_assert" })
    assert_nil colour
  end
=end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '1DC',
  'invalid image_name raises' do
    error = assert_raises(ArgumentError) {
      sss_run({ image_name:INVALID_IMAGE_NAME })
    }
    assert_equal 'image_name:invalid', error.message
  end

  test '3FF',
  'invalid kata_id raises' do
    error = assert_raises(ArgumentError) {
      sss_run({ kata_id:INVALID_KATA_ID })
    }
    assert_equal 'kata_id:invalid', error.message
  end

  test 'C3A',
  'invalid avatar_name raises' do
    error = assert_raises(ArgumentError) {
      sss_run({ avatar_name:INVALID_AVATAR_NAME })
    }
    assert_equal 'avatar_name:invalid', error.message
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  VALID_ALPINE_IMAGE_NAME = 'cyberdojofoundation/gcc_assert'
  VALID_UBUNTU_IMAGE_NAME = 'cyberdojofoundation/clangpp_assert'
  VALID_KATA_ID = '2911DDFD16'
  VALID_AVATAR_NAME = 'salmon'

  INVALID_IMAGE_NAME  = '_cantStartWithSeparator'
  INVALID_KATA_ID     = '345'
  INVALID_AVATAR_NAME = 'polaroid'

end
