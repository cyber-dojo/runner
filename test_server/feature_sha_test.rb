require_relative 'test_base'

class ShaTest < TestBase

  def self.hex_prefix
    'FB3'
  end

  # - - - - - - - - - - - - - - - - -

  test '190', %w( sha is exposed via API ) do
    assert_sha(sha)
  end

end
