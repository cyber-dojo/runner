# frozen_string_literal: true
require_relative 'test_base'

class TimedOutTest < TestBase

  def self.id58_prefix
    '9E9'
  end

  # - - - - - - - - - - - - - - - - -

  test 'B2A', %w(
  when timed_out is false,
  then the traffic-light colour is set
  ) do
    run_cyber_dojo_sh
    refute timed_out?, :timed_out
    assert_equal 'red', colour, :colour
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test 'B2B', %w(
  when run_cyber_dojo_sh does not complete within max_seconds,
  and does not produce output,
  then stdout is empty,
  and stderr is empty,
  and status is 137,
  and timed_out is true,
  and the traffic-light colour is set
  ) do
    named_args = {
      max_seconds: 1,
      changed: { 'hiker.c' =>
        <<~'SOURCE'
        #include "hiker.h"
        int answer(void)
        {
            for(;;);
            return 6 * 7;
        }
        SOURCE
      }
    }
    run_cyber_dojo_sh(named_args)
    assert timed_out?, pretty_result(:timed_out)
    assert stdout.empty?, pretty_result(:stdout)
    assert stderr.empty?, pretty_result(:stderr)
    assert_equal 137, status, pretty_result(:status)
    assert_equal 'amber', colour, pretty_result(:colour)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test '4D7', %w(
  when run_cyber_dojo_sh does not complete in max_seconds,
  and produces output on stdout,
  any flushed stdout is captured (there is some),
  and stderr is empty,
  and status is 137,
  and timed_out is true,
  and the traffic-light colour is set
  ) do
    named_args = {
      max_seconds: 1,
      changed: { 'hiker.c' =>
        <<~'SOURCE'
        #include "hiker.h"
        #include <stdio.h>
        int answer(void)
        {
            // fputs inside the infinite loop busts a
            // file-size ulimit, terminates, no time-out
            // 10000 is enough for stdout to flush
            for(int i = 0; i != 10000; i++)
              fputs("Hello\\n", stdout);
            for(;;);
            return 6 * 7;
        }
        SOURCE
      }
    }
    run_cyber_dojo_sh(named_args)
    assert timed_out?, pretty_result(:timed_out)
    assert stdout.include?('Hello'), pretty_result(:stdout)
    assert stderr.empty?, pretty_result(:stderr)
    assert_equal 137, status, pretty_result(:status)
    assert_equal 'amber', colour, pretty_result(:colour)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test '4D8', %w(
  when run_cyber_dojo_sh does not complete in max_seconds,
  and produces output on stdout,
  any flushed stdout is captured (there is none),
  and stderr is empty,
  and status is usually 137, but occasionally 42 (gzip error),
  and timed_out is true,
  and the traffic-light colour is set
  ) do
    named_args = {
      max_seconds: 1,
      changed: { 'hiker.c' =>
        <<~'SOURCE'
        #include "hiker.h"
        #include <stdio.h>
        int answer(void)
        {
            // not enough output to flush stdout
            fputs("Hello\\nHello\\n", stdout);
            for(;;);
            return 6 * 7;
        }
        SOURCE
      }
    }
    run_cyber_dojo_sh(named_args)
    assert stdout.empty?, pretty_result(:stdout)
    assert stderr.empty?, pretty_result(:stderr)
    assert [42,137].include?(status), pretty_result(:status)
    assert_equal 'amber', colour, pretty_result(:colour)
    assert timed_out?, pretty_result(:timed_out)
  end

end
