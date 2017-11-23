require_relative 'test_base'
require_relative 'image_names'
require_relative '../../src/valid_image_name'

class ValidImageNameTest < TestBase

  include ValidImageName
  include ImageNames

  def self.hex_prefix
    'AF3'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '696', %w( invalid image_names are invalid ) do
    invalid_image_names.each do |invalid_image_name|
      refute valid_image_name?(invalid_image_name)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '697', %w( valid image_name are valid ) do
    valid_image_names.each { |valid_image_name|
      assert valid_image_name?(valid_image_name)
    }
  end

end
