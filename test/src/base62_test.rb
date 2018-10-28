require_relative 'test_base'
require_relative '../../src/base62'

class Base62Test < TestBase

  def self.hex_prefix
    'F3A'
  end

  def alphabet
    Base62.alphabet
  end

  # - - - - - - - - - - - - - - - - - - -

  test '064', %w(
  alphabet has 62 characters (10+26+26) all of which get used ) do
    counts = {}
    Base62.string(5000).chars.each do |ch|
      counts[ch] = true
    end
    assert_equal 62, counts.keys.size
    assert_equal alphabet.chars.sort.join, counts.keys.sort.join
  end

  # - - - - - - - - - - - - - - - - - - -

  test '066', %w(
  string generation is sufficiently random that there is
  no 6-digit string duplicate in 25,000 repeats ) do
    ids = {}
    repeats = 25000
    repeats.times do
      s = Base62.string(6)
      ids[s] ||= 0
      ids[s] += 1
    end
    assert repeats, ids.keys.size
  end

  # - - - - - - - - - - - - - - - - - - -

  test '068', %w(
  string?(s) true ) do
    assert string?('012456789')
    assert string?('abcdefghijklmnopqrstuvwxyz')
    assert string?('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
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
    Base62.string?(s)
  end

end
