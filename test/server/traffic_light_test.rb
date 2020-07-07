# frozen_string_literal: true
require_relative 'test_base'
require_relative 'data/python_pytest'
require_source 'traffic_light'

class TrafficLightTest < TestBase

  def self.id58_prefix
    '22E'
  end

  # - - - - - - - - - - - - - - - - -
  # red, amber, green

  test 'CB0', %w( red traffic-light ) do
    assert_equal 'red', traffic_light_colour(stdout:Test::Data::PythonPytest::STDOUT_RED), log
  end

  test 'CB1', %w( amber traffic-light ) do
    assert_equal 'amber', traffic_light_colour(stdout:Test::Data::PythonPytest::STDOUT_AMBER), log
  end

  test 'CB2', %w( green traffic-light ) do
    assert_equal 'green', traffic_light_colour(stdout:Test::Data::PythonPytest::STDOUT_GREEN), log
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB3', %w( read rag-lambda message is logged once ) do
    assert_log_read_rag_lambda_count 0
    assert_equal 'green', traffic_light_colour(stdout:Test::Data::PythonPytest::STDOUT_GREEN), log
    assert_log_read_rag_lambda_count 1
    assert_equal 'red', traffic_light_colour(stdout:Test::Data::PythonPytest::STDOUT_RED), log
    assert_log_read_rag_lambda_count 1
  end

  # - - - - - - - - - - - - - - - - -

  test 'xJ5', %w( lambdas are cached ) do
    f1 = traffic_light.send('[]', image_name)
    f2 = traffic_light.send('[]', image_name)
    assert f1.equal?(f2), :caching
  end

  # - - - - - - - - - - - - - - - - -

  test 'xJ6', %w( TrafficLight::Fault holds message as JSON ) do
    info = { abc:'sanity', def:'check' }
    fail TrafficLight::Fault, info
  rescue TrafficLight::Fault => error
    assert_equal JSON.pretty_generate(info), error.message
  end

  # - - - - - - - - - - - - - - - - -

  test 'xJ7', %w( lambda status argument is an integer in a string ) do
    assert_equal 'red', traffic_light_colour(status:'0')
  end

  # - - - - - - - - - - - - - - - - -

  test 'xJ8', %w(
  rag-lambda can return a string or a symbol (Postel's Law) ) do
    stub_bash_sheller

    rag = "lambda{|so,se,st| 'red' }"
    bash_stub_capture(docker_run_command) { [rag, '', 0] }
    assert_equal 'red', traffic_light_colour

    rag = "lambda{|so,se,st| :red }"
    bash_stub_capture(docker_run_command) { [rag, '', 0] }
    assert_equal 'red', traffic_light_colour
  end

  # - - - - - - - - - - - - - - - - -
  # faulty

  test 'CB4', %w(
  image_name without a rag-lambda file,
  always gives colour==faulty,
  adds message to log
  ) do
    stub_bash_sheller
    stderr = "cat: can't open '/usr/local/bin/red_amber_green.rb': No such file or directory"
    bash_stub_capture(docker_run_command) { ['', stderr, 1] }
    assert_equal 'faulty', traffic_light_colour
    assert_no_lambda_logged('image_name must have /usr/local/bin/red_amber_green.rb file')
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB5', %w(
  rag-lambda which raises when eval'd,
  gives colour==faulty,
  adds message to log
  ) do
    stub_bash_sheller
    bad_lambda_source = 'not-a-lambda'
    bash_stub_capture(docker_run_command) { [bad_lambda_source, '', 0] }
    assert_equal 'faulty', traffic_light_colour
    context = "exception when eval'ing lambda source"
    klass = 'SyntaxError'
    message = "/app/code/empty_binding.rb:6: syntax error, unexpected '-'\\nnot-a-lambda\\n   ^\\n"
    assert_bad_lambda_logged(context, bad_lambda_source, klass, message)
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB6', %w(
  rag-lambda which raises when called,
  gives colour==faulty,
  adds message to log
  ) do
    stub_bash_sheller
    bad_lambda_source = "lambda{ |so,se,st| fail RuntimeError, '42' }"
    bash_stub_capture(docker_run_command) { [bad_lambda_source, '', 0] }
    assert_equal 'faulty', traffic_light_colour
    context = 'exception when calling lambda source'
    klass = 'RuntimeError'
    message = '42'
    assert_bad_lambda_logged(context, bad_lambda_source, klass, message)
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB7', %w(
  rag-lambda with too few parameters,
  gives colour==faulty,
  adds message to log
  ) do
    stub_bash_sheller
    bad_lambda_source = 'lambda{ |_a,_b| :red }'
    bash_stub_capture(docker_run_command) { [bad_lambda_source, '', 0] }
    assert_equal 'faulty', traffic_light_colour
    context = 'exception when calling lambda source'
    klass = 'ArgumentError'
    message = 'wrong number of arguments (given 3, expected 2)'
    assert_bad_lambda_logged(context, bad_lambda_source, klass, message)
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB8', %w(
  rag-lambda with too many parameters,
  gives colour==faulty,
  adds message to log
  ) do
    stub_bash_sheller
    bad_lambda_source = 'lambda{ |_a,_b,_c,_d| :red }'
    bash_stub_capture(docker_run_command) { [bad_lambda_source, '', 0] }
    assert_equal 'faulty', traffic_light_colour
    context = 'exception when calling lambda source'
    klass = 'ArgumentError'
    message = 'wrong number of arguments (given 3, expected 4)'
    assert_bad_lambda_logged(context, bad_lambda_source, klass, message)
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB9', %w(
  rag-lambda which returns non red/amber/green,
  gives colour==faulty,
  adds message to log
  ) do
    stub_bash_sheller
    bad_lambda_source = 'lambda{|so,se,st| :orange }'
    bash_stub_capture(docker_run_command) { [bad_lambda_source, '', 0] }
    assert_equal 'faulty', traffic_light_colour
    context = "illegal colour; must be one of ['red','amber','green']"
    illegal_colour = 'orange'
    assert_illegal_colour_logged(context, bad_lambda_source, illegal_colour)
  end

  private

  def traffic_light
    @traffic_light ||= TrafficLight.new(context)
  end

  def assert_log_read_rag_lambda_count(expected)
    lines = log.split("\n")
    actual = read_red_amber_green_lambda_message_count(lines)
    assert_equal expected, actual, lines
  end

  def read_red_amber_green_lambda_message_count(lines)
    message = "Read red-amber-green lambda for #{python_pytest_image_name}"
    lines.count { |line| line.include?(message) }
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def traffic_light_colour(options = {})
    image_name = python_pytest_image_name
    @stdout = options.delete(:stdout) || Test::Data::PythonPytest::STDOUT_RED
    @stderr = options.delete(:stderr) || 'unused'
    @status = options.delete(:status) || 0
    traffic_light.colour(image_name, @stdout, @stderr, @status)
  end

  def python_pytest_image_name
    'cyberdojofoundation/python_pytest'
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  def docker_run_command
    [ 'docker run --rm --entrypoint=cat',
      python_pytest_image_name,
      RAG_LAMBDA_FILENAME
    ].join(' ')
  end

  RAG_LAMBDA_FILENAME = '/usr/local/bin/red_amber_green.rb'

  def stub_bash_sheller
    context.instance_exec { @sheller = BashShellerStub.new }
  end

  def bash_stub_capture(command, &block)
    stdout,stderr,status = *block.call
    context.sheller.capture(command, &block)
    @command = command
    @command_stdout = stdout
    @command_stderr = stderr
    @command_status = status
  end

  def assert_no_lambda_logged(context)
    assert_call_info_logged
    assert_logged?("exception:TrafficLight::Fault:", :exception)
    assert_logged?('message:{', :start_of_json)
    assert_logged?("  \"context\": \"#{context}\"", :context)
    assert_logged?("  \"command\": \"#{@command}\"", :command)
    assert_logged?("  \"stdout\": \"#{@command_stdout}\"", :command_stdout)
    assert_logged?("  \"stderr\": \"#{@command_stderr}\"", :command_stderr)
    assert_logged?("  \"status\": #{@command_status}", :command_status)
    assert_logged?('}', :end_of_json)
  end

  def assert_bad_lambda_logged(context, lambda_source, klass, message)
    assert_call_info_logged
    assert_logged?("exception:TrafficLight::Fault:", :exception)
    assert_logged?('message:{', :start_of_json)
    assert_logged?("  \"context\": \"#{context}\"", :context)
    assert_logged?("  \"lambda_source\": \"#{lambda_source}\"", :lambda_source)
    assert_logged?("  \"class\": \"#{klass}\"", :class)
    assert_logged?("  \"message\": \"#{message}\"", :message)
    assert_logged?('}', :end_of_json)
  end

  def assert_illegal_colour_logged(context, lambda_source, illegal_colour)
    assert_call_info_logged
    assert_logged?("exception:TrafficLight::Fault:", :exception)
    assert_logged?('message:{', :start_of_json)
    assert_logged?("  \"context\": \"#{context}\"", :context)
    assert_logged?("  \"lambda_source\": \"#{lambda_source}\"", :lambda_source)
    assert_logged?("  \"illegal_colour\": \"#{illegal_colour}\"", :message)
    assert_logged?('}', :end_of_json)
  end

  def assert_call_info_logged
    assert_logged?('Faulty TrafficLight.colour(image_name,stdout,stderr,status):', :banner)
    assert_logged?("image_name:#{python_pytest_image_name}:", :image_name)
    assert_logged?("stdout:#{@stdout}:", :stdout)
    assert_logged?("stderr:#{@stderr}:", :stderr)
    assert_logged?("status:#{@status}:", :status)
  end

  def assert_logged?(expected, context)
    assert logged?(expected), "\nLOG:#{log}:\nCONTEXT:#{context}:\nEXPECTED:#{expected}:\n"
  end

end
