require_relative 'test_base'
require_relative 'data/image_names'
require_relative '../src/docker/image_name'

class ImageNameTest < TestBase

  def self.hex_prefix
    'AF3'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '696', %w( malformed image_name is false ) do
    MALFORMED_IMAGE_NAMES.each do |s|
      refute Docker::image_name?(s), s
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '697', %w( well-formed image_name is true ) do
    WELL_FORMED_IMAGE_NAMES.each do |s|
      assert Docker::image_name?(s), s
    end
  end

  private

  include Test::Data

end
