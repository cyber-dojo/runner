# frozen_string_literal: true
require_relative '../test_base'
require_code 'random_hex'

class RandomHexTest < TestBase

  def self.id58_prefix
    '4a7'
  end

  # - - - - - - - - - - - - - - - - -

  test 'c91', %w( hex_id(8) is size 8, each char is hex-digit ) do
    size = 8
    512.times do
      assert is_hex?(size, RandomHex.id(size), 0)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'c92', %w( size=0 doesn't work but I don't need that anyway ) do
    error = assert_raises(ArgumentError) { RandomHex.id(0) }
    assert_equal 'wrong number of arguments (given 1, expected 0)', error.message
  end

  # - - - - - - - - - - - - - - - - -

  private

  def is_hex?(n, s, version)
    assert s.is_a?(String), "v(#{version}) not a String"
    assert_equal n, s.size, "v(#{version}) wrong size"
    s.each_char do |ch|
      assert HEX_DIGITS.include?(ch), "v(#{version}) not a hex-digit #{ch}"
    end
  end

  HEX_DIGITS = [*('a'..'z'),*('A'..'Z'),*('0'..'9')]

end
