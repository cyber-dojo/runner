require_relative 'test_base'

class PullerTest < TestBase

  def self.hex_prefix; '4CD0A7F'; end

  # - - - - - - - - - - - - - - - - - - - - -
  # image_pulled?
  # - - - - - - - - - - - - - - - - - - - - -

=begin
  test '5EC',
  'image_pulled?(valid but unpulled image_name) is false' do
    assert_equal false, image_pulled? 'lazybox'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'B22',
  'image_pulled?(valid and pulled image_name) is true' do
    image_pull({image_name:'busybox'})
    assert_equal true, image_pulled? 'busybox'
  end
=end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'D71',
  'image_pulled?(invalid_image name) raises' do
    error = assert_raises(StandardError) {
      image_pulled? INVALID_IMAGE_NAME
    }
    expected = 'RunnerService:image_pulled?:image_name:invalid'
    assert_equal expected, error.message
  end

=begin
  # - - - - - - - - - - - - - - - - - - - - -
  # pull
  # - - - - - - - - - - - - - - - - - - - - -

  test 'A82',
  'image_pull(valid and existing image_name) succeeds and returns true' do
    assert_equal true, image_pull({image_name:'busybox'})
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '667',
  'image_pull(valid non-existing image_name) raises' do
    error = assert_raises(StandardError) {
      image_pull 'non_existent_box'
    }
    expected = 'RunnerService:image_pull:command:docker pull non_existent_box'
    assert_equal expected, error.message
  end
=end

  # - - - - - - - - - - - - - - - - - - - - -

  test '1A7',
  'image_pull(invalid_image name) raises' do
    error = assert_raises(StandardError) {
      image_pull INVALID_IMAGE_NAME
    }
    expected = 'RunnerService:image_pull:image_name:invalid'
    assert_equal expected, error.message
  end

  private

  INVALID_IMAGE_NAME = '_cantStartWithSeparator'

end
