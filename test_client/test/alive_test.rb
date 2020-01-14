require_relative 'test_base'

class AliveTest < TestBase

  def self.hex_prefix
    '74C'
  end

  # - - - - - - - - - - - - - - - - -

  test 'CA2', 'alive?' do
    alive = runner.alive?['alive?']
    assert alive.is_a?(TrueClass) || alive.is_a?(FalseClass)
    assert alive
  end

end
