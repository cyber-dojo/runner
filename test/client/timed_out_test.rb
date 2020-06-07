# frozen_string_literal: true
require_relative 'test_base'

class TimedOutTest < TestBase

  def self.id58_prefix
    'D59'
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test 'FDD',
  '[C,assert] run which does not timeout' do
    run_cyber_dojo_sh
    refute timed_out?, result
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test 'FDC',
  'run with infinite loop times out' do
    from = 'return 6 * 9'
    to = "    for (;;);\n    return 6 * 7;"
    run_cyber_dojo_sh({
      changed_files: { 'hiker.c' => hiker_c.sub(from, to) },
        max_seconds: 3
    })
    assert timed_out?, result
  end

  # - - - - - - - - - - - - - - - - -

  visual_basic_nunit_test 'FDE',
  'run with infinite loop times out' do
    hiker_vb = starting_files['Hiker.vb']
    from = 'Return 6 * 9'
    to = "    while true\nend while\nReturn 6 * 9"
    run_cyber_dojo_sh({
      changed_files: { 'Hiker.vb' => hiker_vb.sub(from, to) },
        max_seconds: 3
    })
    assert timed_out?, result
  end

end
