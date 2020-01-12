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

  test '421', %w( faulty when no red_amber_green.rb file ) do
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

  test '422', %w( faulty when ill-formed lambda ) do
    stub =
      <<~RUBY
      sdf
      RUBY
    assert_stub_rag_lambda_faulty(stub)
  end

  # - - - - - - - - - - - - - - - - -

  test '423', %w( faulty when lambda explictly raises ) do
    stub =
      <<~RUBY
      lambda { |stdout, stderr, status|
        raise ArgumentError.new('wibble')
      }
      RUBY
    assert_stub_rag_lambda_faulty(stub)
  end

  # - - - - - - - - - - - - - - - - -

  test '499', %w( robustness against broken red_amber_green.rb files ) do
    assert false, 'finish robustness tests before deploying'
  end

  private

  def assert_stub_rag_lambda_faulty(stub)
    image_stub = "runner_test_stub:#{id}"
    Dir.mktmpdir do |dir|
      dockerfile = [
        "FROM #{image_name}",
        'COPY stub /usr/local/bin/red_amber_green.rb'
      ].join("\n")
      IO.write("#{dir}/stub", stub)
      IO.write("#{dir}/Dockerfile", dockerfile)
      `docker build --tag #{image_stub} #{dir}`
    end
    run_cyber_dojo_sh({image_name:image_stub})
    `docker image rm #{image_stub}`
    assert_equal 'faulty', traffic_light[:colour]
  end

end
