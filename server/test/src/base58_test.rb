require_relative 'test_base'
require_relative '../../src/base58'

class Base58Test < TestBase

  def self.hex_prefix
    'F3A59'
  end

  test '064', %w(
  alphabet has 58 characters none of which are missed ) do
    counts = {}
    Base58.string(10000).chars.each do |ch|
      counts[ch] = true
    end
    assert_equal 58, counts.keys.size
  end

  # - - - - - - - - - - - - - - - - - - -

  test '066', %w(
  at most one 6-digit string duplicate in 100,000 repeats ) do
    ids = {}
    repeats = 100000
    repeats.times do
      s = Base58.string(6)
      ids[s] ||= 0
      ids[s] += 1
    end
    assert (repeats - ids.keys.size) <= 1
  end

  # - - - - - - - - - - - - - - - - - - -

  test '068', %w(
  string?(s) true/false ) do
    assert string?('012AaEefFgG89Zz')
    refute string?(nil)
    refute string?([])
    refute string?(25)
    refute string?('HIJ') # I (India)
    refute string?('HiJ') # i (india)
    refute string?('NOP') # O (Oscar)
    refute string?('NoP') # o (oscar)
  end

  private

  def string?(s)
    Base58.string?(s)
  end

end
