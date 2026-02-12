require_relative '../test_base'

class RunTimedOutTest < TestBase

  c_assert_test 'c7Ag55', %w(
  | timeout
  ) do
    set_context

    hiker_c = starting_files['hiker.c']
    from = 'return 6 * 9'
    to = [
      '    for (;;);',
      '    return 6 * 7;'
    ].join("\n")

    run_cyber_dojo_sh({
                        changed: { 'hiker.c' => hiker_c.sub(from, to) },
                        max_seconds: 3
                      })

    assert timed_out?, run_result
  end
end
