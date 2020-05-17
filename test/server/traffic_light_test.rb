# frozen_string_literal: true
require_relative 'test_base'
require_relative 'data/python_pytest'
require_relative 'bash_stub'
require 'tmpdir'

class TrafficLightTest < TestBase

  def self.id58_prefix
    '22E'
  end

  def id58_teardown
    bash = externals.bash
    externals.bash = nil
    if bash.is_a?(BashStub)
      bash.teardown
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB1', %w(
  for a straight red only the colour is returned
  ) do
    assert_equal 'red', traffic_light(PythonPytest::STDOUT_RED, '', 0)
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB2', %w(
  for a straight amber only the colour is returned
  ) do
    assert_equal 'amber', traffic_light(PythonPytest::STDOUT_AMBER, '', 0)
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB3', %w(
  for a straight green only the colour is returned
  ) do
    assert_equal 'green', traffic_light(PythonPytest::STDOUT_GREEN, '', 0)
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB4', %w(
  image_name without a rag-lambda file always gives colour==faulty
  ) do
    externals.bash = BashStub.new
    command = docker_run_command
    stdout = ''
    stderr = "cat: can't open '/usr/local/bin/red_amber_green.rb': No such file or directory"
    status = 1
    externals.bash.stub_run(command, stdout, stderr, status)
    with_captured_log {
      @bulb = traffic_light(PythonPytest::STDOUT_RED, '', 0)
    }
    assert_equal 'faulty', @bulb
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB5', %w(
  image_name with rag-lambda which raises when eval'd gives colour==faulty
  ) do
    externals.bash = BashStub.new
    command = docker_run_command
    stdout = 'ssss'
    stderr = ''
    status = 0
    externals.bash.stub_run(command, stdout, stderr, status)
    with_captured_log {
      @bulb = traffic_light(PythonPytest::STDOUT_RED, '', 0)
    }
    assert_equal 'faulty', @bulb
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB6', %w(
  image_name with rag-labda which raises when called gives colour==faulty
  ) do
    externals.bash = BashStub.new
    command = docker_run_command
    stdout = 'lambda{|so,se,st| ssss}'
    stderr = ''
    status = 0
    externals.bash.stub_run(command, stdout, stderr, status)
    with_captured_log {
      @bulb = traffic_light(PythonPytest::STDOUT_RED, '', 0)
    }
    assert_equal 'faulty', @bulb
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB7', %w(
  image_name with rag-labda which returns non red/amber/green gives colour==faulty
  ) do
    externals.bash = BashStub.new
    command = docker_run_command
    stdout = 'lambda{|so,se,st| :orange }'
    stderr = ''
    status = 0
    externals.bash.stub_run(command, stdout, stderr, status)
    with_captured_log {
      @bulb = traffic_light(PythonPytest::STDOUT_RED, '', 0)
    }
    assert_equal 'faulty', @bulb
  end

  private

  include Test::Data

  def traffic_light(stdout, stderr, status)
    externals.traffic_light.colour(python_pytest_image_name, stdout, stderr, status)
  end

  def docker_run_command
    [ 'docker run --rm --entrypoint=cat',
      python_pytest_image_name,
      rag_lambda_filename
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

  def rag_lambda_filename
    '/usr/local/bin/red_amber_green.rb'
  end

end
