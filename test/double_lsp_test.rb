# frozen_string_literal: true
require_relative 'test_base'

class DoubleLanguagesStartPointsTest < TestBase

  def self.id58_prefix
    'DDx'
  end

  # - - - - - - - - - - - - - - - - - - - - - -

  test 'as3', %w(
  LSP is alive ) do
    assert languages_start_points.alive?.is_a?(TrueClass)
  end

  test 'as4', %w(
  LSP is ready ) do
    assert languages_start_points.ready?.is_a?(TrueClass)
  end

  test 'as5', %w(
  LSP sha is SHA of git commit which created its docker image
  ) do
    assert_sha(languages_start_points.sha)
  end

end
