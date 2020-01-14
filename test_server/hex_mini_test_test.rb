# frozen_string_literal: true
require_relative 'test_base'

class HexMiniTestTest < TestBase

  def self.hex_prefix
    '89c'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'C80',
  'hex-test-id is available via environment variable' do
    assert_equal '89cC80', ENV['CYBER_DOJO_HEX_TEST_ID']
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '57B',
  'hex-test-id is also available via a method',
  'and is the hex_prefix concatenated with the hex-id' do
    assert_equal '89c57B', hex_test_id
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '18F',
  'hex-test-name is available via a method' do
    assert_equal 'hex-test-name is available via a method', hex_test_name
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'D30',
  'hex-test-name can be long',
  'and split over many',
  'comma separated lines',
  'and will automatically be',
  'joined with spaces' do
    expected = [
      'hex-test-name can be long',
      'and split over many',
      'comma separated lines',
      'and will automatically be',
      'joined with spaces'
    ].join(' ')
    assert_equal expected, hex_test_name
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'D31', %w(
    hex-test-name can be long
    and split over many lines
    with %w syntax
    and will automatically be
    joined with spaces
  ) do
    expected = [
      'hex-test-name can be long',
      'and split over many lines',
      'with %w syntax',
      'and will automatically be',
      'joined with spaces'
    ].join(' ')
    assert_equal expected, hex_test_name
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'e3a', %w( hex digits can be UPPERCASE or lowercase ) do
    assert_equal '89ce3a', ENV['CYBER_DOJO_HEX_TEST_ID']
    assert_equal '89ce3a', hex_test_id
  end

end
