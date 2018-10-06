require_relative 'test_base'
require_relative '../../src/base58'

class Base58Test < TestBase

  def self.hex_prefix
    'F3A'
  end

  # - - - - - - - - - - - - - - - - - - -

  test '068', %w(
  string?(s) true ) do
    assert string?('012AaEefFgG89Zz')
    assert string?('345BbCcDdEeFfGg')
    assert string?('678HhJjKkLlMmNn')
    assert string?('999PpQqRrSsTtUu')
    assert string?('263VvWwXxYyZz11')
  end

  # - - - - - - - - - - - - - - - - - - -

  test '069', %w(
  string?(s) false ) do
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
