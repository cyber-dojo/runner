require_relative 'test_base'
require_relative '../src/base58'

class Base58Test < TestBase

  def self.hex_prefix
    'F3A'
  end

  def alphabet
    Base58.alphabet
  end

  # - - - - - - - - - - - - - - - - - - -

  test '064', %w(
  alphabet has 58 characters (10+26+26) all of which get used ) do
    counts = {}
    Base58.string(5000).chars.each do |ch|
      counts[ch] = true
    end
    assert_equal 58, counts.keys.size
    assert_equal alphabet.chars.sort.join, counts.keys.sort.join
  end

  # - - - - - - - - - - - - - - - - - - -

  test '066', %w(
  string generation is sufficiently random that there is
  no 6-digit string duplicate in 25,000 repeats ) do
    ids = {}
    repeats = 25000
    repeats.times do
      s = Base58.string(6)
      ids[s] ||= 0
      ids[s] += 1
    end
    assert repeats, ids.keys.size
  end

  # - - - - - - - - - - - - - - - - - - -

  test '068', %w(
  string?(s) true ) do
    assert string?('012456789')
    assert string?('abcdefghjklmnpqrstuvwxyz')
    assert string?('ABCDEFGHJKLMNPQRSTUVWXYZ')
  end

  # - - - - - - - - - - - - - - - - - - -

  test '069', %w(
  string?(s) false ) do
    refute string?(nil)
    refute string?([])
    refute string?(25)
    refute string?('£$%^&*()')
  end

  private

  def string?(s)
    Base58.string?(s)
  end

end
