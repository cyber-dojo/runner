require_relative '../test_base'
require_code 'tgz'

class TgzTest < TestBase

  test 'e51H3s', %w[simple tgz round-trip] do
    files_in = {
      'hello.txt' => 'greetings earthlings...',
      'hiker.c' => '#include <stdio.h>'
    }
    assert_equal files_in, TGZ.files(TGZ.of(files_in))
  end

  # - - - - - - - - - - - - - - - - - -

  test 'e51H4s', %w[simple tgz round-trip of nothing] do
    assert_equal({}, TGZ.files(TGZ.of({})))
  end
end
