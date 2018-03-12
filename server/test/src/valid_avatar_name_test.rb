require_relative 'test_base'
require_relative '../../src/valid_avatar_name'

class ValidAvatarNameTest < TestBase

  include ValidAvatarName

  def self.hex_prefix
    '7BEBD'
  end

  # - - - - - - - - - - - - - - - - -

  test 'CBD',
  'valid-avatar-name is true' do
    assert valid_avatar_name?('lion')
    assert valid_avatar_name?('tiger')
    assert valid_avatar_name?('salmon')
  end

  # - - - - - - - - - - - - - - - - -

  test 'CBE',
  'invalid-avatar-name is false' do
    refute valid_avatar_name?('chub')
    refute valid_avatar_name?('perch')
  end

end
