require_relative 'test_base'
require_relative '../../src/well_formed_avatar_name'

class WellFormedAvatarNameTest < TestBase

  include WellFormedAvatarName

  def self.hex_prefix
    '7BEBD'
  end

  # - - - - - - - - - - - - - - - - -

  test 'CBD',
  'well-formed-avatar-name is true' do
    assert well_formed_avatar_name?('lion')
    assert well_formed_avatar_name?('tiger')
    assert well_formed_avatar_name?('salmon')
  end

  # - - - - - - - - - - - - - - - - -

  test 'CBE',
  'malformed-avatar-name is false' do
    refute well_formed_avatar_name?('chub')
    refute well_formed_avatar_name?('perch')
    refute well_formed_avatar_name?(nil)
    refute well_formed_avatar_name?([])
    refute well_formed_avatar_name?(['lion'])
    refute well_formed_avatar_name?({})
    refute well_formed_avatar_name?({'lion'=>nil})
    refute well_formed_avatar_name?(true)
    refute well_formed_avatar_name?('true')
  end

end
