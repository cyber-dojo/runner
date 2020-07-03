# frozen_string_literal: true
require_relative 'test_base'
require_source 'synchronized_set'

class SynchronizedSetTest < TestBase

  def self.id58_prefix
    'wK9'
  end

  # - - - - - - - - - - - - - - - - -

  test 'd9f', %w(
  initially empty
  ) do
    s = SynchronizedSet.new
    assert_equal 0, s.size
  end

  # - - - - - - - - - - - - - - - - -

  test 'd9g', %w(
  values not added are not included
  ) do
    s = SynchronizedSet.new
    refute s.include?(42)
  end

  # - - - - - - - - - - - - - - - - -

  test 'd9h', %w(
  added values are included
  ) do
    s = SynchronizedSet.new
    s.add?(42)
    assert s.include?(42)
    assert_equal 1, s.size
  end

  # - - - - - - - - - - - - - - - - -

  test 'd9j', %w(
  deleted values are not included
  ) do
    s = SynchronizedSet.new
    s.add?(42)
    s.delete(42)
    refute s.include?(42)
    assert_equal 0, s.size
  end

  # - - - - - - - - - - - - - - - - -

  test 'd9k', %w(
  add? returns non-nil when value is not already included,
  returns nil when value is already included
  ) do
    s = SynchronizedSet.new
    refute_nil s.add?(42)
    assert s.include?(42)
    assert_equal 1, s.size
    assert_nil s.add?(42)
    assert s.include?(42)
    assert_equal 1, s.size
  end

end
