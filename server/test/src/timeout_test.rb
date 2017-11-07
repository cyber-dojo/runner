require_relative 'test_base'

class TimeoutTest < TestBase

  def self.hex_prefix
    '45B57'
  end

  def hex_setup
    set_image_name image_for_test
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'B2B', %w( [gcc,assert]
  when test-code does not complete in max_seconds
  and does not produce output
  the output is empty, and
  the colour is timed_out
  ) do
    in_kata {
      as(salmon) {
        hiker_c_content = [
          '#include "hiker.h"',
          'int answer(void)',
          '{',
          '    for(;;); ',
          '    return 6 * 7;',
          '}'
        ].join("\n")
        named_args = {
          changed_files: { 'hiker.c' => hiker_c_content },
            max_seconds: 2
        }
        assert_run_times_out(named_args)
      }
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '4D7', %w( [gcc,assert]
  when run(test-code) does not complete in max_seconds
  and does produce output
  the output is nonetheless empty, and
  the colour is timed_out
  ) do
    in_kata {
      as(salmon) {
        hiker_c_content = [
          '#include "hiker.h"',
          '#include <stdio.h>',
          'int answer(void)',
          '{',
          '    for(;;)',
          '        puts("Hello");',
          '    return 6 * 7;',
          '}'
        ].join("\n")
        named_args = {
          changed_files: { 'hiker.c' => hiker_c_content },
            max_seconds: 2
        }
        assert_run_times_out(named_args)
      }
    }
  end

end
