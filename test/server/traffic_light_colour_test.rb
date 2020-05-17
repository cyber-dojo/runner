# frozen_string_literal: true
require_relative 'test_base'
require_relative 'data/python_pytest'
require 'tmpdir'

class TrafficLightColourTest < TestBase

  def self.id58_prefix
    '22E'
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB1', %w(
  for a straight red only the colour is returned
  ) do
    colour = bulb(PythonPytest::STDOUT_RED, '', 0)
    assert_equal 'red', colour
  end

  # - - - - - - - - - - - - - - - - -

  test 'CB2', %w(
  for a straight amber only the colour is returned
  ) do
    colour = bulb(PythonPytest::STDOUT_AMBER, '', 0)
    assert_equal 'amber', colour
  end

  # - - - - - - - - - - - - - - - - -
  test 'CB3', %w(
  for a straight green only the colour is returned
  ) do
    colour = bulb(PythonPytest::STDOUT_GREEN, '', 0)
    assert_equal 'green', colour
  end

  private

  include Test::Data

  def bulb(stdout, stderr, status)
    externals.traffic_light[PythonPytest::IMAGE_NAME].call(stdout, stderr, status)
  end

end
