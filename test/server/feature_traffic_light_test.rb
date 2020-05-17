# frozen_string_literal: true
require_relative 'test_base'
require 'tmpdir'

class TrafficLightTest < TestBase

  def self.id58_prefix
    '7B7'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '9DA', %w( stdout is not being whitespace stripped ) do
    stdout = assert_cyber_dojo_sh('printf " hel\nlo "')
    assert_equal " hel\nlo ", stdout
    # NB: A trailing newline _is_ being stripped
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '9DB', %w( red traffic-light, no diagnostics ) do
    run_cyber_dojo_sh
    assert_equal 'red', colour, result
    assert_nil diagnostic, :diagnostic
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '9DC', %w( amber traffic-light, no diagnostics ) do
    syntax_error = starting_files[filename_6x9].sub('6 * 9', '6 * 9sdf')
    run_cyber_dojo_sh({changed:{filename_6x9=>syntax_error}})
    assert_equal 'amber', colour, result
    assert_nil diagnostic, :diagnostic
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '9DD', %w( green traffic-light, no diagnostics ) do
    passing = starting_files[filename_6x9].sub('6 * 9', '6 * 7')
    run_cyber_dojo_sh({changed:{filename_6x9=>passing}})
    assert_equal 'green', colour, result
    assert_nil diagnostic, :diagnostic
  end

  # - - - - - - - - - - - - - - - - -

  test '421', %w(
  when rag-lambda is missing,
  then the colour is faulty,
  and diagnostics are added to the json result
  ) do
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
      with_captured_log {
        run_cyber_dojo_sh({image_name:image_stub})
      }
      expected_info = "no /usr/local/bin/red_amber_green.rb in #{image_stub}"
      assert_equal 'faulty', colour
      assert_equal image_stub, diagnostic['image_name'], :image_name
      assert_equal id, diagnostic['id'], :id
      assert_equal expected_info, diagnostic['info'], :info
      assert_nil diagnostic['name'], :name
      assert_nil diagnostic['message'], :message
      assert_nil diagnostic['rag_lambda'], :rag_lambda
    ensure
      shell.assert("docker image rm #{image_stub}")
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '422', %w(
  when rag-lambda has an eval exception,
  then the colour is faulty,
  and diagnostics are added to the json result
  ) do
    stub =
      <<~RUBY
      sdf
      RUBY
    image_stub = run_cyber_dojo_image_stubbed_with(stub)
    expected_info = 'eval(rag_lambda) raised an exception'
    expected_message = "undefined local variable or method `sdf'"
    assert_equal 'faulty', colour, :colour
    assert_equal image_stub, diagnostic['image_name'], :image_name
    assert_equal id, diagnostic['id'], :id
    assert_equal expected_info, diagnostic['info'], :info
    assert_equal 'NameError', diagnostic['name'], :name
    assert diagnostic['message'][0].start_with?(expected_message), :message
    assert_equal stub.split("\n"), diagnostic['rag_lambda'], :rag_lambda
  end

  # - - - - - - - - - - - - - - - - -

  test '423', %w(
  when rag-lambda has a call exception,
  then the colour is faulty,
  and diagnostics are added to the json result
  ) do
    stub =
      <<~RUBY
      lambda { |stdout, stderr, status|
        raise ArgumentError.new('wibble')
      }
      RUBY
    image_stub = run_cyber_dojo_image_stubbed_with(stub)
    expected_info = 'rag_lambda.call raised an exception'
    assert_equal 'faulty', colour, :colour
    assert_equal image_stub, diagnostic['image_name'], :image_name
    assert_equal id, diagnostic['id'], :id
    assert_equal expected_info, diagnostic['info'], :info
    assert_equal 'ArgumentError', diagnostic['name'], :name
    assert_equal ['wibble'], diagnostic['message'], :message
    assert_equal stub.split("\n"), diagnostic['rag_lambda'], :rag_lambda
  end

  # - - - - - - - - - - - - - - - - -

  test '424', %w(
  when the rag-lambda returns non red/amber/green,
  then the colour is faulty,
  and diagnostics are added to the json result
  ) do
    stub =
    <<~RUBY
    lambda { |stdout, stderr, status|
      return :orange
    }
    RUBY
    image_stub = run_cyber_dojo_image_stubbed_with(stub)
    expected_info = "rag_lambda.call is 'orange' which is not 'red'|'amber'|'green'"
    assert_equal 'faulty', colour, :colour
    assert_equal image_stub, diagnostic['image_name'], :image_name
    assert_equal id, diagnostic['id'], :id
    assert_equal expected_info, diagnostic['info'], :info
    assert_nil diagnostic['name'], :name
    assert_nil diagnostic['message'], :message
    assert_equal stub.split("\n"), diagnostic['rag_lambda'], :rag_lambda
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
    image_stub = run_cyber_dojo_image_stubbed_with(stub)
    expected_info = 'rag_lambda.call raised an exception'
    expected_message = 'wrong number of arguments (given 3, expected 2)'
    assert_equal 'faulty', colour, :colour
    assert_equal image_stub, diagnostic['image_name'], :image_name
    assert_equal id, diagnostic['id'], :id
    assert_equal expected_info, diagnostic['info'], :info
    assert_equal 'ArgumentError', diagnostic['name'], :name
    assert_equal [expected_message], diagnostic['message'], :message
    assert_equal stub.split("\n"), diagnostic['rag_lambda'], :rag_lambda
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
    image_stub = run_cyber_dojo_image_stubbed_with(stub)
    expected_info = 'rag_lambda.call raised an exception'
    expected_message = 'wrong number of arguments (given 3, expected 4)'
    assert_equal 'faulty', colour, :colour
    assert_equal image_stub, diagnostic['image_name'], :image_name
    assert_equal id, diagnostic['id'], :id
    assert_equal expected_info, diagnostic['info'], :info
    assert_equal 'ArgumentError', diagnostic['name'], :name
    assert_equal [expected_message], diagnostic['message'], :message
    assert_equal stub.split("\n"), diagnostic['rag_lambda'], :rag_lambda
  end

  # - - - - - - - - - - - - - - - - -

  test '427', %w(
  when the rag-lambda has an eval SyntaxError exception,
  then the colour is faulty,
  and diagnostics are added to the json result
  ) do
    stub = 'return :red adsd'
    image_stub = run_cyber_dojo_image_stubbed_with(stub)
    expected_info = 'eval(rag_lambda) raised an exception'
    expected_message = 'syntax error, unexpected tIDENTIFIER'
    assert_equal 'faulty', colour, :colour
    assert_equal image_stub, diagnostic['image_name'], :image_name
    assert_equal id, diagnostic['id'], :id
    assert_equal expected_info, diagnostic['info'], :info
    assert_equal 'SyntaxError', diagnostic['name'], :name
    assert diagnostic['message'][0].include?(expected_message), :message
    assert_equal stub.split("\n"), diagnostic['rag_lambda'], :rag_lambda
  end

  # - - - - - - - - - - - - - - - - -

  test '428', %w(
  when the rag-lambda raises an Exception directly,
  then the colour is faulty,
  and diagnostics are added to the json result
  ) do
    stub = 'raise Exception, "fubar"'
    image_stub = run_cyber_dojo_image_stubbed_with(stub)
    expected_info = 'eval(rag_lambda) raised an exception'
    assert_equal 'faulty', colour, :colour
    assert_equal image_stub, diagnostic['image_name'], :image_name
    assert_equal id, diagnostic['id'], :id
    assert_equal expected_info, diagnostic['info'], :info
    assert_equal 'Exception', diagnostic['name'], :name
    assert_equal ['fubar'], diagnostic['message'], :message
    assert_equal stub.split("\n"), diagnostic['rag_lambda'], :rag_lambda
  end

  private

  def filename_6x9
    starting_files.keys.find { |filename|
      starting_files[filename].include?('6 * 9')
    }
  end

  # - - - - - - - - - - - - - - - - -

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
      image_stub
    ensure
      shell.assert("docker image rm #{image_stub}")
    end
  end

end
