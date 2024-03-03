# frozen_string_literal: true
require_relative '../test_base'
require_code 'externals/random'

class RandomTest < TestBase
  def self.id58_prefix
    '4a7'
  end

  test 'c91', %w[random.hex8 is size 8, each char is hex-digit] do
    512.times do
      assert hex8?(Random.new.hex8)
    end
  end

  private

  def hex8?(str)
    assert str.is_a?(String), 'not a String'
    assert_equal 8, str.size, 'wrong size'
    str.each_char do |char|
      assert HEX_DIGITS.include?(char), "not a hex-digit #{char}"
    end
  end

  HEX_DIGITS = [*('a'..'z'), *('A'..'Z'), *('0'..'9')].freeze
end
