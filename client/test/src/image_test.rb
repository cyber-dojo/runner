require_relative 'test_base2'

class ImageTest < TestBase2

  def self.hex_prefix
    '4CD0A'
  end

  # - - - - - - - - - - - - - - - - - - - - -
  # pull
  # - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'B21',
  'pull is false when image_name repository does not exist' do
    refute image_pull({ image_name: "#{cdf}/lazybox" })
  end

  # - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'B22',
  'pull is true when image_name is valid and exists' do
    assert image_pull({ image_name: VALID_IMAGE_NAME } )
  end

  # - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'B23',
  'pull raises when image_name is invalid' do
    error = assert_raises(StandardError) {
      image_pull({ image_name: INVALID_IMAGE_NAME })
    }
    expected = 'RunnerService:image_pull:image_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'B24',
  'pull raises when kata_id is invalid' do
    error = assert_raises(StandardError) {
      image_pull({ kata_id: INVALID_KATA_ID })
    }
    expected = 'RunnerService:image_pull:kata_id:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -
  # pulled?
  # - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'EF6',
  'pulled? raises when image_name is invalid' do
    error = assert_raises(StandardError) {
      image_pulled?({ image_name: INVALID_IMAGE_NAME })
    }
    expected = 'RunnerService:image_pulled?:image_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'EF7',
  'pulled? raises when kata_id is invalid' do
    error = assert_raises(StandardError) {
      image_pulled?({ kata_id: INVALID_KATA_ID })
    }
    expected = 'RunnerService:image_pulled?:kata_id:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'EF4',
  'pulled? is false when image_name is valid but unpulled' do
    refute image_pulled?({ image_name: 'lazybox' })
  end

  # - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'EF5',
  'pulled? is true when image_name is valid and pulled' do
    image_pull({ image_name: VALID_IMAGE_NAME })
    assert image_pulled?({ image_name: VALID_IMAGE_NAME })
  end

end
