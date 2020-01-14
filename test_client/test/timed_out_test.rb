# frozen_string_literal: true
require_relative 'test_base'

class TimedOutTest < TestBase

  def self.hex_prefix
    'D59'
  end

  # - - - - - - - - - - - - - - - - -

  test '3DD',
  '[C,assert] run which does not timeout' do
    run_cyber_dojo_sh
    refute timed_out?, result
  end

  # - - - - - - - - - - - - - - - - -

  test '3DC',
  '[C,assert] run with infinite loop times out' do
    from = 'return 6 * 9'
    to = "    for (;;);\n    return 6 * 7;"
    run_cyber_dojo_sh({
      changed_files: { 'hiker.c' => hiker_c.sub(from, to) },
        max_seconds: 3
    })
    assert timed_out?, result
  end

end
