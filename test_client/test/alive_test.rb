require_relative 'test_base'

class ReadyTest < TestBase

  def self.hex_prefix
    '74C'
  end

  # - - - - - - - - - - - - - - - - -

  test 'CA2', 'ready?' do
    ready = runner.ready?
    assert ready.is_a?(TrueClass) || ready.is_a?(FalseClass)
    assert ready
  end

end
