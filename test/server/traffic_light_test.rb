# frozen_string_literal: true
require_relative 'test_base'
require_relative 'data/python_pytest'
require_relative 'bash_stub'
require_src 'result_logger'
require_src 'traffic_light'
require 'json'

class TrafficLightTest < TestBase

  def self.id58_prefix
    '22E'
  end

  def id58_setup
    @result = { 'log' => '' }
    @logger = ResultLogger.new(@result)
  end

  def id58_teardown
    bash = externals.bash
    externals.bash = nil
    if bash.is_a?(BashStub)
      bash.teardown
    end
  end

  attr_reader :result, :logger

  def pretty_log
    @result['log']
  end

  def assert_pretty_log_include?(expected, context)
    assert pretty_log.include?(expected), pretty_log + "\nCONTEXT:#{context}\n"
  end

  # - - - - - - - - - - - - - - - - -

  test 'xJ6', %w( sanity check FaultyBulbError class ) do
    info = { abc:'sanity', def:'check' }
    fail TrafficLight::Fault, info
  rescue TrafficLight::Fault => error
    assert_equal JSON.pretty_generate(info), error.message
  end

  # - - - - - - - - - - - - - - - - -

  test 'xJ7', %w( status is an integer ) do
    gcc_assert = 'cyberdojofoundation/gcc_assert'
    assert_equal 'green', externals.traffic_light.colour(logger, gcc_assert, '', '', '0')
    assert pretty_log.empty?, pretty_log
  end

  # - - - - - - - - - - - - - - - - -

  test 'xJ8', %w(
  allow rag-lambda to return string colour (Postel's Law) ) do
    externals.bash = BashStub.new
    postel = "lambda{|_so,_se,_st| 'red' }"
    bash_stub_run(docker_run_command, postel, '', 0)
    assert_equal 'red', traffic_light('ignored', 'ignored', 0)
    assert pretty_log.empty?, pretty_log
  end

  test 'xJ9', %w(
  allow rag-lambda to return string symbol (Postel's Law) ) do
    externals.bash = BashStub.new
    postel = "lambda{|_so,_se,_st| :red }"
    bash_stub_run(docker_run_command, postel, '', 0)
    assert_equal 'red', traffic_light('ignored', 'ignored', 0)
    assert pretty_log.empty?, pretty_log
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB1', %w(
  for a working red,
  the colour is returned,
  nothing is added to the log
  ) do
    assert_equal 'red', traffic_light(PythonPytest::STDOUT_RED, '', 0), pretty_log
    assert pretty_log.empty?, pretty_log
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB2', %w(
  for a working amber,
  the colour is returned,
  nothing is added to the log
  ) do
    assert_equal 'amber', traffic_light(PythonPytest::STDOUT_AMBER, '', 0)
    assert pretty_log.empty?, pretty_log
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB3', %w(
  for a working green,
  the colour is returned,
  nothing is added to the log
  ) do
    assert_equal 'green', traffic_light(PythonPytest::STDOUT_GREEN, '', 0)
    assert pretty_log.empty?, pretty_log
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB4', %w(
  image_name without a rag-lambda file,
  always gives colour==faulty,
  adds message to log
  ) do
    externals.bash = BashStub.new
    stub_stderr = "cat: can't open '/usr/local/bin/red_amber_green.rb': No such file or directory"
    bash_stub_run(docker_run_command, '', stub_stderr, 1)
    with_captured_log {
      assert_equal 'faulty', traffic_light(PythonPytest::STDOUT_RED, '', 0)
    }
    assert_docker_cat_logged('image_name must have /usr/local/bin/red_amber_green.rb file')
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB5', %w(
  image_name with rag-lambda which raises when eval'd,
  gives colour==faulty,
  adds message to log
  ) do
    externals.bash = BashStub.new
    bad_lambda_source = 'not-a-lambda'
    bash_stub_run(docker_run_command, bad_lambda_source, '', 0)
    assert_equal 'faulty', traffic_light(PythonPytest::STDOUT_RED, '', 0)
    context = "exception when eval'ing lambda source"
    klass = 'SyntaxError'
    message = "/app/code/empty.rb:5: syntax error, unexpected '-'\\nnot-a-lambda\\n   ^"
    assert_bad_lambda_logged(context, bad_lambda_source, klass, message)
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB6', %w(
  image_name with rag-lambda which raises when called,
  gives colour==faulty,
  adds message to log
  ) do
    externals.bash = BashStub.new
    bad_lambda_source = "lambda{ |_so,_se,_st| fail RuntimeError, '42' }"
    bash_stub_run(docker_run_command, bad_lambda_source, '', 0)
    assert_equal 'faulty', traffic_light(PythonPytest::STDOUT_RED, '', 0)
    context = 'exception when calling lambda source'
    klass = 'RuntimeError'
    message = '42'
    assert_bad_lambda_logged(context, bad_lambda_source, klass, message)
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB7', %w(
  image_name with rag-lambda with too few parameters,
  gives colour==faulty,
  adds message to log
  ) do
    externals.bash = BashStub.new
    bad_lambda_source = 'lambda{ |_1,_2| :red }'
    bash_stub_run(docker_run_command, bad_lambda_source, '', 0)
    assert_equal 'faulty', traffic_light(PythonPytest::STDOUT_RED, '', 0)
    context = 'exception when calling lambda source'
    klass = 'ArgumentError'
    message = 'wrong number of arguments (given 3, expected 2)'
    assert_bad_lambda_logged(context, bad_lambda_source, klass, message)
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB8', %w(
  image_name with rag-lambda with too many parameters,
  gives colour==faulty,
  adds message to log
  ) do
    externals.bash = BashStub.new
    bad_lambda_source = 'lambda{ |_1,_2,_3,_4| :red }'
    bash_stub_run(docker_run_command, bad_lambda_source, '', 0)
    assert_equal 'faulty', traffic_light(PythonPytest::STDOUT_RED, '', 0)
    context = 'exception when calling lambda source'
    klass = 'ArgumentError'
    message = 'wrong number of arguments (given 3, expected 4)'
    assert_bad_lambda_logged(context, bad_lambda_source, klass, message)
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB9', %w(
  image_name with rag-lambda which returns non red/amber/green,
  gives colour==faulty,
  adds message to log
  ) do
    externals.bash = BashStub.new
    bad_lambda_source = 'lambda{|so,se,st| :orange }'
    bash_stub_run(docker_run_command, bad_lambda_source, '', 0)
    bulb = traffic_light(PythonPytest::STDOUT_RED, '', 0)
    assert_equal 'faulty', bulb
    context = "illegal colour; must be one of ['red','amber','green']"
    illegal_colour = 'orange'
    assert_illegal_colour_logged(context, bad_lambda_source, illegal_colour)
  end

  private

  include Test::Data

  def traffic_light(stdout, stderr, status)
    @stdout = stdout
    @stderr = stderr
    @status = status
    externals.traffic_light.colour(logger, python_pytest_image_name, stdout, stderr, status)
  end

  def docker_run_command
    [ 'docker run --rm --entrypoint=cat',
      python_pytest_image_name,
      RAG_LAMBDA_FILENAME
    ].join(' ')
  end

  def python_pytest_image_name
    if externals.bash.is_a?(BashStub)
      # Have to avoid cache to ensure bash.run() call is made
      "cyberdojofoundation/python_pytest_#{id58.downcase}"
    else
      'cyberdojofoundation/python_pytest'
    end
  end

  RAG_LAMBDA_FILENAME = '/usr/local/bin/red_amber_green.rb'

  def bash_stub_run(command, stdout, stderr, status)
    externals.bash.stub_run(command, stdout, stderr, status)
    @command = command
    @command_stdout = stdout
    @command_stderr = stderr
    @command_status = status
  end

  def assert_docker_cat_logged(context)
    assert_call_info_log
    assert_pretty_log_include?("exception:TrafficLight::Fault:", :exception)
    assert_pretty_log_include?('message:{', :start_of_json)
    assert_pretty_log_include?("  \"context\": \"#{context}\"", :context)
    assert_pretty_log_include?("  \"command\": \"#{@command}\"", :command)
    assert_pretty_log_include?("  \"stdout\": \"#{@command_stdout}\"", :command_stdout)
    assert_pretty_log_include?("  \"stderr\": \"#{@command_stderr}\"", :command_stderr)
    assert_pretty_log_include?("  \"status\": #{@command_status}", :command_status)
    assert_pretty_log_include?('}', :end_of_json)
  end

  def assert_bad_lambda_logged(context, lambda_source, klass, message)
    assert_call_info_log
    assert_pretty_log_include?("exception:TrafficLight::Fault:", :exception)
    assert_pretty_log_include?('message:{', :start_of_json)
    assert_pretty_log_include?("  \"context\": \"#{context}\"", :context)
    assert_pretty_log_include?("  \"lambda_source\": \"#{lambda_source}\"", :lambda_source)
    assert_pretty_log_include?("  \"class\": \"#{klass}\"", :class)
    assert_pretty_log_include?("  \"message\": \"#{message}\"", :message)
    assert_pretty_log_include?('}', :end_of_json)
  end

  def assert_illegal_colour_logged(context, lambda_source, illegal_colour)
    assert_call_info_log
    assert_pretty_log_include?("exception:TrafficLight::Fault:", :exception)
    assert_pretty_log_include?('message:{', :start_of_json)
    assert_pretty_log_include?("  \"context\": \"#{context}\"", :context)
    assert_pretty_log_include?("  \"lambda_source\": \"#{lambda_source}\"", :lambda_source)
    assert_pretty_log_include?("  \"illegal_colour\": \"#{illegal_colour}\"", :message)
    assert_pretty_log_include?('}', :end_of_json)
  end

  def assert_call_info_log
    assert_pretty_log_include?('Faulty TrafficLight.colour(image_name,stdout,stderr,status):', :banner)
    assert_pretty_log_include?("image_name:#{python_pytest_image_name}:", :image_name)
    assert_pretty_log_include?("stdout:#{@stdout}:", :stdout)
    assert_pretty_log_include?("stderr:#{@stderr}:", :stderr)
    assert_pretty_log_include?("status:#{@status}:", :status)
  end

end
