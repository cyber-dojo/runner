require_relative 'test_base'
require 'tmpdir'

class TrafficLightTest < TestBase

  def self.hex_prefix
    '7B7'
  end

  # - - - - - - - - - - - - - - - - -

  test '9DA', %w( stdout is not being whitespace stripped ) do
    stdout = assert_cyber_dojo_sh('printf " hello \n"')
    assert_equal " hello \n", stdout
  end

  # - - - - - - - - - - - - - - - - -

  test '9DB', %w( red traffic-light ) do
    run_cyber_dojo_sh
    assert_equal 'red', colour, :colour
    assert_nil diagnostic, :diagnostic
  end

  # - - - - - - - - - - - - - - - - -

  test '9DC', %w( amber traffic-light ) do
    syntax_error = starting_files['Hiker.cs'].sub('6 * 9', '6 * 9sdf')
    run_cyber_dojo_sh({changed:{ 'Hiker.cs' => syntax_error}})
    assert_equal 'amber', colour, :colour
    assert_nil diagnostic, :diagnostic
  end

  # - - - - - - - - - - - - - - - - -

  test '9DD', %w( green traffic-light ) do
    fixed = starting_files['Hiker.cs'].sub('6 * 9', '6 * 7')
    run_cyber_dojo_sh({changed:{ 'Hiker.cs' => fixed}})
    assert_equal 'green', colour, :colour
    assert_nil diagnostic, :diagnostic
  end

  # - - - - - - - - - - - - - - - - -

  test '421', %w( faulty when no red_amber_green.rb file ) do
    image_stub = "runner_test_stub:#{id}"
    Dir.mktmpdir do |dir|
      dockerfile = [
        "FROM #{image_name}",
        'RUN rm /usr/local/bin/red_amber_green.rb'
      ].join("\n")
      IO.write("#{dir}/Dockerfile", dockerfile)
      shell.assert("docker build --tag #{image_stub} #{dir}")
    end
    begin
      run_cyber_dojo_sh({image_name:image_stub})
      assert_equal 'faulty', colour
      assert false, 'todo: add diagnostic'
    ensure
      shell.assert("docker image rm #{image_stub}")
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '422', %w(
  when rag-lambda has an eval exception,
  then colour is mapped to faulty,
  and diagnostics are added to the json result
  ) do
    stub =
      <<~RUBY
      sdf
      RUBY
    run_cyber_dojo_image_stubbed_with(stub)
    expected_info = 'eval(rag_lambda) raised an exception'
    expected_message = "undefined local variable or method `sdf'"
    assert_equal 'faulty', colour, :colour
    assert_equal expected_info, diagnostic['info'], :info
    assert diagnostic['message'].start_with?(expected_message), :message
    assert_equal stub, diagnostic['rag_lambda'], :rag_lambda
  end

  # - - - - - - - - - - - - - - - - -

  test '423', %w(
  when rag-lambda has a call exception,
  then the colour is mapped to faulty,
  and diagnostics are added to the json result
  ) do
    stub =
      <<~RUBY
      lambda { |stdout, stderr, status|
        raise ArgumentError.new('wibble')
      }
      RUBY
    run_cyber_dojo_image_stubbed_with(stub)
    expected_info = 'rag_lambda.call raised an exception'
    expected_message = 'wibble'
    assert_equal 'faulty', colour, :colour
    assert_equal expected_info, diagnostic['info'], :info
    assert_equal expected_message, diagnostic['message'], :message
    assert_equal stub, diagnostic['rag_lambda'], :rag_lambda
  end

  # - - - - - - - - - - - - - - - - -

  test '424', %w(
  when the rag-lambda returns non red/amber/green,
  then the colour is mapped to faulty,
  and diagnostics are added to the json result
  ) do
    stub =
    <<~RUBY
    lambda { |stdout, stderr, status|
      return :orange
    }
    RUBY
    run_cyber_dojo_image_stubbed_with(stub)
    expected_info = "rag_lambda.call is 'orange' which is not 'red'|'amber'|'green'"
    assert_equal 'faulty', colour, :colour
    assert_equal expected_info, diagnostic['info'], :info
    assert_nil diagnostic['message'], :message
    assert_equal stub, diagnostic['rag_lambda'], :rag_lambda
  end

  # - - - - - - - - - - - - - - - - -

  test '425', %w(
  when the rag-lambda has too few parameters,
  then the colour is faulty,
  and diagnostics are added to the json result
  ) do
    stub =
    <<~RUBY
    lambda { |stdout, stderr|
      return :red
    }
    RUBY
    run_cyber_dojo_image_stubbed_with(stub)
    expected_info = 'rag_lambda.call raised an exception'
    expected_message = 'wrong number of arguments (given 3, expected 2)'
    assert_equal 'faulty', colour, :colour
    assert_equal expected_info, diagnostic['info'], :info
    assert_equal expected_message, diagnostic['message'], :message
    assert_equal stub, diagnostic['rag_lambda'], :rag_lambda
  end

  # - - - - - - - - - - - - - - - - -

  test '426', %w(
  when the rag-lambda has too many parameters,
  then the colour is faulty,
  and diagnostics are added to the json result
  ) do
    stub =
    <<~RUBY
    lambda { |stdout, stderr, status, extra|
      return :red
    }
    RUBY
    run_cyber_dojo_image_stubbed_with(stub)
    expected_info = 'rag_lambda.call raised an exception'
    expected_message = 'wrong number of arguments (given 3, expected 4)'
    assert_equal 'faulty', colour, :colour
    assert_equal expected_info, diagnostic['info'], :info
    assert_equal expected_message, diagnostic['message'], :message
    assert_equal stub, diagnostic['rag_lambda'], :rag_lambda
  end

  # - - - - - - - - - - - - - - - - -

  test '427', %w(
  when the rag-lambda has an eval SyntaxError exception,
  then the colour is mapped to faulty,
  and diagnostics are added to the json result
  ) do
    stub = 'return :red adsd'
    run_cyber_dojo_image_stubbed_with(stub)
    expected_info = 'eval(rag_lambda) raised an exception'
    expected_message = 'syntax error, unexpected tIDENTIFIER'
    assert_equal 'faulty', colour, :colour
    assert_equal expected_info, diagnostic['info'], :info
    assert diagnostic['message'].include?(expected_message), :message
    assert_equal stub, diagnostic['rag_lambda'], :rag_lambda
  end

  # - - - - - - - - - - - - - - - - -

  test '428', %w(
  when the rag-lambda raises an Exception directly,
  then the colour is mapped to faulty,
  and diagnostics are added to the json result
  ) do
    stub = 'raise Exception, "fubar"'
    run_cyber_dojo_image_stubbed_with(stub)
    expected_info = 'eval(rag_lambda) raised an exception'
    expected_message = 'fubar'
    assert_equal 'faulty', colour, :colour
    assert_equal expected_info, diagnostic['info'], :info
    assert_equal expected_message, diagnostic['message'], :message
    assert_equal stub, diagnostic['rag_lambda'], :rag_lambda
  end

  private

  def run_cyber_dojo_image_stubbed_with(stub)
    image_stub = "runner_test_stub:#{id}"
    Dir.mktmpdir do |dir|
      dockerfile = [
        "FROM #{image_name}",
        'COPY stub /usr/local/bin/red_amber_green.rb'
      ].join("\n")
      IO.write("#{dir}/stub", stub)
      IO.write("#{dir}/Dockerfile", dockerfile)
      shell.assert("docker build --tag #{image_stub} #{dir}")
    end
    begin
      run_cyber_dojo_sh({image_name:image_stub})
    ensure
      shell.assert("docker image rm #{image_stub}")
    end
  end

end
