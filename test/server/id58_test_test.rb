# frozen_string_literal: true
require_relative 'test_base'

class Id58TestTest < TestBase

  def self.id58_prefix
    '89c'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'C80',
  'test-id is available via environment variable' do
    assert_equal '89cC80', ENV['ID58']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '57B',
  'test-id is also available via a method',
  'and is the id58_prefix concatenated with the test-id' do
    assert_equal '89c57B', id58
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '18F',
  'test-name is available via a method' do
    assert_equal 'test-name is available via a method', name58
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'D30',
  'test-name can be long',
  'and split over many',
  'comma separated lines',
  'and will automatically be',
  'joined with spaces' do
    expected = [
      'test-name can be long',
      'and split over many',
      'comma separated lines',
      'and will automatically be',
      'joined with spaces'
    ].join(' ')
    assert_equal expected, name58
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'D31', %w(
    test-name can be long
    and split over many lines
    with %w syntax
    and will automatically be
    joined with spaces
  ) do
    expected = [
      'test-name can be long',
      'and split over many lines',
      'with %w syntax',
      'and will automatically be',
      'joined with spaces'
    ].join(' ')
    assert_equal expected, name58
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'e3a', %w( digits can be UPPERCASE or lowercase ) do
    assert_equal '89ce3a', ENV['ID58']
    assert_equal '89ce3a', id58
  end

end
