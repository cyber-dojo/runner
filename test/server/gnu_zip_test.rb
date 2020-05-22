# frozen_string_literal: true
require_relative 'test_base'
require_src 'gnu_zip'
require_src 'gnu_unzip'

class GnuZipTest < TestBase

  def self.id58_prefix
    'CD4'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '4A1', 'simple gzip round-trip' do
    expected = 'sdgfadsfghfghsfhdfghdfghdfgh'
    zipped = Gnu.zip(expected)
    actual = Gnu.unzip(zipped)
    assert_equal expected, actual
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '4A2', %w( how to get empty tgz for stubbing ) do
    zipped = Gnu.zip(Tar::Writer.new.tar_file)
    assert_equal({}, Tar::Reader.new(Gnu.unzip(zipped)).files)
  end

end
