# frozen_string_literal: true
require_relative '../test_base'
require_code 'gnu_zip'
require_code 'gnu_unzip'

module Server
  class GnuZipTest < TestBase

    def self.id58_prefix
      'Cw4'
    end

    # - - - - - - - - - - - - - - - - - - - - -

    test '4A1', %w( simple gzip round-trip of non-empty string ) do
      expected = 'sdgfadsfghfghsfhdfghdfghdfgh'
      zipped = Gnu.zip(expected)
      actual = Gnu.unzip(zipped)
      assert_equal expected, actual
    end

    # - - - - - - - - - - - - - - - - - - - - -

    test '4A2', %w( simple gzip round-trip of empty string ) do
      expected = ''
      zipped = Gnu.zip(expected)
      actual = Gnu.unzip(zipped)
      assert_equal expected, actual
    end

  end
end
