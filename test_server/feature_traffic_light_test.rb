require_relative 'test_base'
require 'tmpdir'

class TrafficLightTest < TestBase

  def self.hex_prefix
    '7B7'
  end

  # - - - - - - - - - - - - - - - - -

  test '9DA', %w( stdout is not being whitespace stripped ) do
    stdout = assert_cyber_dojo_sh('echo " hello "')
    assert_equal " hello \n", stdout
  end

  # - - - - - - - - - - - - - - - - -

  test '9DB', %w( red traffic-light ) do
    run_cyber_dojo_sh
    assert_equal 'red', traffic_light[:colour]
  end

  # - - - - - - - - - - - - - - - - -

  test '9DC', %w( amber traffic-light ) do
    syntax_error = starting_files['Hiker.cs'].sub('6 * 9', '6 * 9sdf')
    run_cyber_dojo_sh({changed:{ 'Hiker.cs' => syntax_error}})
    assert_equal 'amber', traffic_light[:colour]
  end

  # - - - - - - - - - - - - - - - - -

  test '9DD', %w( green traffic-light ) do
    syntax_error = starting_files['Hiker.cs'].sub('6 * 9', '6 * 7')
    run_cyber_dojo_sh({changed:{ 'Hiker.cs' => syntax_error}})
    assert_equal 'green', traffic_light[:colour]
  end

  # - - - - - - - - - - - - - - - - -

  test '8A1', %w( faulty when no red_amber_green.rb file ) do
    # Make an image with a /sandbox user+dir but no rag-lambda file
    image_stub = "runner_test_stub:#{id}"
    Dir.mktmpdir do |dir|
      dockerfile = [
        "FROM #{image_name}",
        'RUN rm /usr/local/bin/red_amber_green.rb'
      ].join("\n")
      IO.write("#{dir}/Dockerfile", dockerfile)
      `docker build --tag #{image_stub} #{dir}`
    end
    run_cyber_dojo_sh({image_name:image_stub})
    `docker image rm #{image_stub}`
    assert_equal 'faulty', traffic_light[:colour]
  end

  # - - - - - - - - - - - - - - - - -

  test '8A2', %w( robustness against broken red_amber_green.rb files ) do
    # I need to generate new images with a modified
    #   /usr/local/bin/red_amber_green.rb file
    # Plan is
    # 0. get the image-name from the manifest.
    # 1. get the rag-lambda source frim the image.
    # 2. open a tmp-dir
    # 3. create a modified red_amber_green.rb file
    # 4. create a new Dockerfile FROM the image
    # 5. Dockerfile will use COPY to overwrite red_amber_green.rb
    # 6. [docker build] to create a new image tagged with test id.
    # 7. use that tagged image_name in a run_cyber_dojo_sh call.
    rag_src = assert_cyber_dojo_sh('cat /usr/local/bin/red_amber_green.rb')
    assert rag_src.start_with?("\nlambda {")
    #puts rag_src
    #Dir.mktmpdir do |dir|
      #puts "My new temp dir:#{dir}:#{dir.class.name}:"
    #end
    assert false, 'finish robustness tests before deploying'
  end

end