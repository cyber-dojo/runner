require_relative 'test_base'

class ImageTest < TestBase

  def self.hex_prefix
    '4CD0A'
  end

  # - - - - - - - - - - - - - - - - - - - - -
  # pull
  # - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'B21',
  'pull is false when image_name repository does not exist' do
    refute image_pull({ image_name: 'docker/lazybox' })
  end

  # - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'B22',
  'pull is true when image_name is valid and exists' do
    assert image_pull({ image_name: VALID_IMAGE_NAME } )
  end

  # - - - - - - - - - - - - - - - - - - - - -
  # pulled?
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
