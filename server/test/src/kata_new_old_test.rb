require_relative 'test_base'

class KataNewOldTest < TestBase

  def self.hex_prefix
    '20A7A'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'DBC', %w( resurrection requires kata_new to work after kata_old ) do
    kata_new
    kata_old
    kata_new
    kata_old
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'DBD', %w( kata_new is idempotent because the runner is stateless ) do
    kata_new
    kata_new
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'DBE', %w( kata_old is idempotent because the runner is stateless ) do
    kata_old
    kata_old
  end

end
