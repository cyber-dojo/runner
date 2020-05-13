require_relative 'test_base'
require_relative 'data/python_pytest'
require_relative 'http_stub'
require 'json'

class ColourTest < TestBase

  def self.id58_prefix
    'm60'
  end

  # - - - - - - - - - - - - - - - - -

  test '6A1', %w(
  for a straight red only the colour is returned
  ) do
    result = colour(PythonPytest::IMAGE_NAME, id, PythonPytest::STDOUT_RED, '', '0')
    assert_equal({'colour' => 'red'}, result)
  end

  test '6A2', %w(
  for a straight amber only the colour is returned
  ) do
    result = colour(PythonPytest::IMAGE_NAME, id, PythonPytest::STDOUT_AMBER, '', '0')
    assert_equal({'colour' => 'amber'}, result)
  end

  test '6A3', %w(
  for a straight green only the colour is returned
  ) do
    result = colour(PythonPytest::IMAGE_NAME, id, PythonPytest::STDOUT_GREEN, '', '0')
    assert_equal({'colour' => 'green'}, result)
  end

  # - - - - - - - - - - - - - - - - -

  test '6A4', %w(
  when image-name is well-formed but non-existent,
  then runner raises,
  and the colour is mapped to faulty,
  and a diagnostic is added to the json result
  ) do
    image_name = 'anything-not-cached'
    assert_faulty(image_name, id, 'o1', 'e3', '0') do |error|
      info = 'runner.run_cyber_dojo_sh() raised an exception'
      assert_equal info, error['info'], :info
      assert_nil error['source'], :source
      json = JSON.parse!(error['message'])
      body = JSON.parse!(json['body'])
      assert_equal '/run_cyber_dojo_sh', json['path'], :path
      assert_equal image_name, body['image_name'], :image_name
      assert_equal id, body['id'], :id
      assert_equal 'RunnerService', json['class'], :class
      assert json['message'].is_a?(String), :message
      assert json['backtrace'].is_a?(Array), :backtrace
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '5A3', %w(
  when rag-lambda has an eval exception,
  then colour is mapped to faulty,
  and a diagnostic is added to the json result
  ) do
    stub =
      <<~RUBY
      sdf
      RUBY

    assert_lambda_stub_faulty(stub) do |error|
      expected_info = 'eval(lambda) raised an exception'
      expected_message = "undefined local variable or method `sdf' for"
      assert_equal expected_info, error['info']
      assert_equal stub, error['source']
      assert error['message'].start_with?(expected_message), error
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '5A4', %w(
  when rag-lambda has a call exception,
  then the colour is mapped to faulty,
  and a diagnostic is added to the json result
  ) do
    stub =
      <<~RUBY
      lambda { |stdout, stderr, status|
        raise ArgumentError.new('wibble')
      }
      RUBY
    assert_lambda_stub_faulty(stub) do |error|
      expected_info = 'call(lambda) raised an exception'
      expected_message = 'wibble'
      assert_equal expected_info, error['info']
      assert_equal expected_message, error['message']
      assert_equal stub, error['source']
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '5A5', %w(
  when the rag-lambda returns non red/amber/green,
  then the colour is mapped to faulty,
  and a diagnostic is added to the json result
  ) do
    stub =
    <<~RUBY
    lambda { |stdout, stderr, status|
      return :orange
    }
    RUBY
    assert_lambda_stub_faulty(stub) do |error|
      expected_info = "call(lambda) is 'orange' which is not 'red'|'amber'|'green'"
      assert_equal expected_info, error['info']
      assert_nil error['message']
      assert_equal stub, error['source']
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '5A6', %w(
    too few parameters is a call-exception, mapped to colour faulty
  ) do
    stub =
    <<~RUBY
    lambda { |stdout, stderr|
      return :red
    }
    RUBY
    assert_lambda_stub_faulty(stub) do |error|
      expected_info = 'call(lambda) raised an exception'
      expected_message = 'wrong number of arguments (given 3, expected 2)'
      assert_equal expected_info, error['info']
      assert_equal expected_message, error['message']
      assert_equal stub, error['source']
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '5A7',
  %w( too many parameters is a call-exception, mapped to colour faulty ) do
    stub =
    <<~RUBY
    lambda { |stdout, stderr, status, extra|
      return :red
    }
    RUBY
    assert_lambda_stub_faulty(stub) do |error|
      expected_info = 'call(lambda) raised an exception'
      expected_message = 'wrong number of arguments (given 3, expected 4)'
      assert_equal expected_info, error['info']
      assert_equal expected_message, error['message']
      assert_equal stub, error['source']
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '5A8', %w(
  when rag-lambda has an eval SyntaxError exception,
  then colour is mapped to faulty,
  and a diagnostic is added to the json result
  ) do
    stub = 'return :red adsd'
    assert_lambda_stub_faulty(stub) do |error|
      expected_info = 'eval(lambda) raised an exception'
      assert_equal expected_info, error['info']
      assert error['message'].include?('syntax error, unexpected tIDENTIFIER')
      assert_equal stub, error['source']
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '5A9', %w(
  when rag-lambda raises Exception directly,
  then colour is mapped to faulty,
  and a diagnostic is added to the json result
  ) do
    stub = 'raise Exception, "fubar"'
    assert_lambda_stub_faulty(stub) do |error|
      expected_info = 'eval(lambda) raised an exception'
      expected_message = 'fubar'
      assert_equal expected_info, error['info']
      assert_equal expected_message, error['message']
      assert_equal stub, error['source']
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '5AA', %w(
  when rag-lambda raises Exception indirectly,
  then colour is mapped to faulty,
  and a diagnostic is added to the json result
  ) do
    stub = 'raise Exception "fubar"' # no comma
    assert_lambda_stub_faulty(stub) do |error|
      expected_info = 'eval(lambda) raised an exception'
      assert_equal expected_info, error['info']
      assert error['message'].include?("undefined method `Exception' for Empty:Module")
      assert_equal stub, error['source']
    end
  end

  private

  include Test::Data

  def assert_lambda_stub_faulty(rag_src)
    externals.instance_exec { @http = HttpStub }
    HttpStub.stub_request({
      'run_cyber_dojo_sh' => {
        'stdout' => {
          'content' => rag_src
        }
      }
    })
    assert_faulty(PythonPytest::IMAGE_NAME, id, 'o34', 'e67', '3') do |rd,od|
      HttpStub.unstub_request
      yield rd,od
    end
  end

  # - - - - - - - - - - - - - - - - -

  def assert_faulty(image_name, id, stdout, stderr, status)
    with_captured_stdout_stderr {
      colour(image_name, id, stdout, stderr, status)
    }
    assert_equal '', @stderr
    assert_equal @result, JSON.parse(@stdout)

    assert_equal 'faulty', @result.delete('colour'), :colour
    assert_equal image_name, @result['diagnostic'].delete('image_name'), :image_name
    assert_equal id, @result['diagnostic'].delete('id'), :id
    assert_equal stdout, @result['diagnostic'].delete('stdout'), :stdout
    assert_equal stderr, @result['diagnostic'].delete('stderr'), :stderr
    assert_equal status, @result['diagnostic'].delete('status'), :status
    yield @result['diagnostic']
  end

end
