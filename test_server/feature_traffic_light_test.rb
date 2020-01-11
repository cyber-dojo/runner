require_relative 'test_base'

class TrafficLightTest < TestBase

  def self.hex_prefix
    '7B7'
  end

  # - - - - - - - - - - - - - - - - -

  test '9DA', %w( start-point files colour is red ) do
    # In order to properly test traffic-light-colour I will need
    # to generate new images with a modified
    #   /usr/local/bin/red_amber_green.rb file
    # Plan to do this is
    # 0. get the manifest which includes image-name and start-point files.
    # 1. get the name of the image from the manifest
    # 2. open a tmp-dir
    # 3. save a modified red_amber_green.rb file
    # 4. save a new Dockerfile FROM the image
    # 5. Dockerfile will use COPY to overwrite red_amber_green.rb
    # 6. [docker build] to create a new image tagged with test id.
  end

end
