# frozen_string_literal: true
require_relative 'test_base'

class DoubleLanguagesStartPointsTest < TestBase

  def self.id58_prefix
    'DDx'
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  test 'as3', %w(
  its alive ) do
    assert languages_start_points.alive?.is_a?(TrueClass)
  end

  test 'as4', %w(
  its ready ) do
    assert languages_start_points.ready?.is_a?(TrueClass)
  end

  test 'as5', %w(
  sha is SHA of git commit which created docker image
  ) do
    assert_sha(languages_start_points.sha)    
  end

end
