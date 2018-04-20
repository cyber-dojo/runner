require_relative 'test_base'
require_relative 'image_names'
require_relative '../../src/well_formed_image_name'

class WellFormedImageNameTest < TestBase

  include WellFormedImageName
  include ImageNames

  def self.hex_prefix
    'AF3A5'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '696', %w( malformed image_name is false ) do
    malformed_image_names.each do |malformed_image_name|
      refute well_formed_image_name?(malformed_image_name)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '697', %w( well-formed image_name is true ) do
    well_formed_image_names.each { |well_formed_image_name|
      assert well_formed_image_name?(well_formed_image_name)
    }
  end

end
