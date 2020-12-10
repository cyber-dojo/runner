# frozen_string_literal: true
require_relative '../test_base'
require_code 'sandbox'

class SandboxTest < TestBase

  def self.id58_prefix
    'd2b'
  end

  # - - - - - - - - - - - - - - - - - -

  test 'd55', %w( empty files no-ops ) do
    assert_equal({}, Sandbox.in({}))
    assert_equal({}, Sandbox.out({}))
  end

  # - - - - - - - - - - - - - - - - - -

  test 'd56', %w(
  Sandbox.in prefixes filenames with sandbox/
  note there is no leading slash
  because tar prefers relative paths
  ) do
    greetings = 'greetings earthlings...'
    code = '#include <stdio.h>'
    sandboxed = Sandbox.in({
      'hello.txt' => greetings,
      'hiker.c' => code
    })
    expected = {
      'sandbox/hello.txt' => greetings,
      'sandbox/hiker.c' => code
    }
    assert_equal expected, sandboxed
  end

  # - - - - - - - - - - - - - - - - - -

  test 'd57', %w( Sandbox.out reverses Sandbox.in ) do
    vogon_greeting = 'People of earth, your attention please'
    header = '#include <stdlib.h>'
    unsandboxed = Sandbox.out({
      'sandbox/hello.txt' => vogon_greeting,
      'sandbox/hiker.h' => header
    })
    expected = {
      'hello.txt' => vogon_greeting,
      'hiker.h' => header
    }
    assert_equal expected, unsandboxed
  end

end
