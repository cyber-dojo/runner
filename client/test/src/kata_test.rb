require_relative 'test_base'

class KataTest < TestBase

  def self.hex_prefix
    'D2E7E'
  end

  multi_os_test 'D87',
  %w( kata_new/kata_old are no-ops for API compatibility ) do
    kata_new
    kata_old
  end

end
