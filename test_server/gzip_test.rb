require_relative 'test_base'
require_relative '../src/gzip'
require_relative '../src/ungzip'

class GZipTest < TestBase

  def self.hex_prefix
    'CD4'
  end

  test '4A1', 'simple gzip round-trip' do
    expected = 'sdgfadsfghfghsfhdfghdfghdfgh'
    zipped = gzip(expected)
    actual = ungzip(zipped)
    assert_equal expected, actual
  end

end
