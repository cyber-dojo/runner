require_relative 'test_base'

class ImageTest < TestBase

  def self.hex_prefix
    '4CD0A'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'B21',
  %w( pull is false when image_name repository does not exist,
      pull is true  when image_name is valid and exists ) do
    refute image_pull({ image_name: 'docker/lazybox' })
    assert image_pull({ image_name: VALID_IMAGE_NAME } )
  end

  # - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'EF4',
  %w( pulled? is false when image_name is valid but unpulled,
      pulled? is true  when image_name is valid and pulled ) do
    refute image_pulled?({ image_name: 'lazybox' })
    image_pull({ image_name: VALID_IMAGE_NAME })
    assert image_pulled?({ image_name: VALID_IMAGE_NAME })
  end

end
