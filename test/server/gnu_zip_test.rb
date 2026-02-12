require_relative '../test_base'
require_code 'gnu_zip'
require_code 'gnu_unzip'

class GnuZipTest < TestBase

  test 'Cw44A1', %w[simple gzip round-trip of non-empty string] do
    expected = 'sdgfadsfghfghsfhdfghdfghdfgh'
    zipped = Gnu.zip(expected)
    actual = Gnu.unzip(zipped)
    assert_equal expected, actual
  end

  test 'Cw44A2', %w[simple gzip round-trip of empty string] do
    expected = ''
    zipped = Gnu.zip(expected)
    actual = Gnu.unzip(zipped)
    assert_equal expected, actual
  end
end
