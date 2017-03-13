require_relative 'test_base'
require_relative '../../src/all_avatars_names'

class AllAvatarsNamesTest < TestBase

  include AllAvatarsNames

  def self.hex_prefix; '7BE'; end

  # - - - - - - - - - - - - - - - - -

  test '229',
  'avatars_names are in sorted order for uid-indexing' do
    assert_equal all_avatars_names.sort, all_avatars_names
  end

  # - - - - - - - - - - - - - - - - -

  test 'CBC',
  'avatars_names are unique in their first 8 chars which matters',
  'because on Alpine, [ps] truncates the user name to 8 chars' do
    # This affects: alligator, butterfly, hummingbird
    # jellyfish, kingfisher, porcupine
    short_names = all_avatars_names.map { |name| name[0..7] }
    assert_equal short_names.uniq.size, all_avatars_names.size
  end

end
