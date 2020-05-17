# frozen_string_literal: true
require_relative 'test_base'
require_src 'random_hex'
require 'benchmark'

class RandomHexTest < TestBase

  def self.id58_prefix
    '4a7'
  end

  # - - - - - - - - - - - - - - - - -

  test 'c91', %w( hex_id(8) is size 8, each char is hex-digit ) do
    size = 8
    512.times do
      assert is_hex?(size, RandomHex.id(size), 0)
      assert is_hex?(size, v1(size), 1)
      assert is_hex?(size, v2(size), 2)
      assert is_hex?(size, v3(size), 3)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test 'c92', %w( size=0 doesnt work but I don't need that anyway ) do
    error = assert_raises(ArgumentError) { RandomHex.id(0) }
    assert_equal 'wrong number of arguments (given 1, expected 0)', error.message
  end

  # - - - - - - - - - - - - - - - - -

  test 'c94', %w( its the fastest of the 4 algorithm I tried ) do
    n,size = 512,8
    t3 = Benchmark.realtime { n.times { v3(size) } }
    t2 = Benchmark.realtime { n.times { v2(size) } }
    t1 = Benchmark.realtime { n.times { v1(size) } }
    # occasionally t1 is close. Do t0 last to give it best chance!
    t0 = Benchmark.realtime { n.times { RandomHex.id(size) } }
    assert t0 < t1, "t=#{t0} , t1 is faster #{t1} "
    assert t0 < t2, "t=#{t0} , t2 is faster #{t2} "
    assert t0 < t3, "t=#{t0} , t3 is faster #{t3} "
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

  def v1(n)
    HEX_DIGITS.shuffle[0,n].join
  end

  def v2(n)
    n.times.map{HEX_DIGITS.sample}.join
  end

  def v3(n)
    Array.new(n){HEX_DIGITS.sample}.join
  end

end
