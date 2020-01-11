require_relative 'test_base'
require 'tmpdir'

class TrafficLightTest < TestBase

  def self.hex_prefix
    '7B7'
  end

  # - - - - - - - - - - - - - - - - -

  test '9DB', %w( stdout is not being whitespace stripped ) do
    stdout = assert_cyber_dojo_sh('echo " hello "')
    assert_equal " hello \n", stdout
  end

  test '9DA', %w( start-point files colour is red ) do
    # In order to properly test traffic-light-colour I will need
    # to generate new images with a modified
    #   /usr/local/bin/red_amber_green.rb file
    # Plan to do this is
    # 0. get the image-name from the manifest.
    # 1. get the rag-lambda source frim the image.
    # 2. open a tmp-dir
    # 3. save a modified red_amber_green.rb file
    # 4. save a new Dockerfile FROM the image
    # 5. Dockerfile will use COPY to overwrite red_amber_green.rb
    # 6. [docker build] to create a new image tagged with test id.
    rag_src = assert_cyber_dojo_sh('cat /usr/local/bin/red_amber_green.rb')
    assert rag_src.start_with?("\nlambda {")
    #puts rag_src
    #Dir.mktmpdir do |dir|
      #puts "My new temp dir:#{dir}:#{dir.class.name}:"
    #end
  end

end
