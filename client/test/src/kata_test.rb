require_relative 'test_base'

class KataTest < TestBase

  def self.hex_prefix
    'D2E7E'
  end

  test 'D87', %w( kata_new is a no-op for API compatibility ) do
    kata_new
  end

  test 'D88', %w( kata_old is a no-op for API compatibility ) do
    kata_old
  end

end
