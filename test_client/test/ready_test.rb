require_relative 'test_base'

class AliveTest < TestBase

  def self.hex_prefix
    'A86'
  end

  # - - - - - - - - - - - - - - - - -

  test '15D', 'alive?' do
    alive = runner.alive?
    assert alive.is_a?(TrueClass) || alive.is_a?(FalseClass)
    assert alive
  end

end
