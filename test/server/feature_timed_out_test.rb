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
    refute_timed_out
    assert_equal 'red', colour, :colour
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test 'B2B', %w(
  when run_cyber_dojo_sh does not complete within max_seconds
  and does not produce output
  then stdout is empty,
  and timed_out is true,
  and the traffic-light colour is not set
  ) do
    named_args = {
      changed: { 'hiker.c' => quiet_infinite_loop },
      max_seconds: 2
    }
    with_captured_log {
      run_cyber_dojo_sh(named_args)
    }
    assert_timed_out
    assert_equal '', stdout, :stdout
    assert_equal '', stderr, :stderr
    refute colour?, :colour?
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test '4D7', %w(
  when run_cyber_dojo_sh does not complete in max_seconds
  and produces output on stdout
  the captured stdout never gets sent
  and timed_out is true,
  and the traffic-light colour is not set
  ) do
    named_args = {
      changed: { 'hiker.c' => loud_infinite_loop },
      max_seconds: 2
    }
    with_captured_log {
      run_cyber_dojo_sh(named_args)
    }
    assert_timed_out
    assert_equal '', stdout, :stdout
    refute colour?, :colour?
  end

  private

  def colour?
    result.has_key?('colour')
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def quiet_infinite_loop
    <<~SOURCE
    #include "hiker.h"
    int answer(void)
    {
        for(;;);
        return 6 * 7;
    }
    SOURCE
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def loud_infinite_loop
    <<~SOURCE
    #include "hiker.h"
    #include <stdio.h>
    int answer(void)
    {
        for (int i = 0; i != 1000; i++)
          fputs("Hello\\n", stdout);
        fflush(stdout);
        for(;;);
        return 6 * 7;
    }
    SOURCE
  end

end
