require_relative 'test_base'

class ImageTest < TestBase

  def self.hex_prefix; '4CD0A7F'; end

  # - - - - - - - - - - - - - - - - - - - - -
  # pull
  # - - - - - - - - - - - - - - - - - - - - -

  test 'B23',
  'raises when image_name is invalid' do
    error = assert_raises(StandardError) {
      image_pull({ image_name:INVALID_IMAGE_NAME })
    }
    expected = 'RunnerService:image_pull:image_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'B24',
  'raises when kata_id is invalid' do
    error = assert_raises(StandardError) {
      image_pull({ kata_id:INVALID_KATA_ID })
    }
    expected = 'RunnerService:image_pull:kata_id:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'B21',
  'false when image_name is valid but does not exist' do
    refute image_pull({ image_name:"#{cdf}/lazybox" })
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'B22',
  'true when image_name is valid and exists' do
    assert image_pull({ image_name:"#{cdf}/gcc_assert"} )
  end

  # - - - - - - - - - - - - - - - - - - - - -
  # pulled?
  # - - - - - - - - - - - - - - - - - - - - -

  test 'EF6',
  'raises when image_name is invalid' do
    error = assert_raises(StandardError) {
      image_pulled?({ image_name:INVALID_IMAGE_NAME })
    }
    expected = 'RunnerService:image_pulled?:image_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'EF7',
  'raises when kata_id is invalid' do
    error = assert_raises(StandardError) {
      image_pulled?({ kata_id:INVALID_KATA_ID })
    }
    expected = 'RunnerService:image_pulled?:kata_id:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'EF4',
  'false when image_name is valid but unpulled' do
    refute image_pulled?({ image_name:'lazybox' })
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'EF5',
  'true when image_name is valid and pulled' do
    image_pull
    assert image_pulled?
  end

end
