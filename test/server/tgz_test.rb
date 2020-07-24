# frozen_string_literal: true
require_relative '../test_base'
require_source 'tgz'

module Server
  class TgzTest < TestBase

    def self.id58_prefix
      'e51'
    end

    # - - - - - - - - - - - - - - - - - -

    test 'H3s', %w( simple tgz round-trip ) do
      files_in = {
        'hello.txt' => 'greetings earthlings...',
        'hiker.c' => '#include <stdio.h>'
      }
      assert_equal files_in, TGZ.files(TGZ.of(files_in))
    end

    # - - - - - - - - - - - - - - - - - -

    test 'H4s', %w( simple tgz round-trip of nothing ) do
      assert_equal({}, TGZ.files(TGZ.of({})))
    end

  end
end
