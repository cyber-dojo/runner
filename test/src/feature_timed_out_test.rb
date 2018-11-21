require_relative 'test_base'

class TimedOutTest < TestBase

  def self.hex_prefix
    '9E9'
  end

  # - - - - - - - - - - - - - - - - -

  test 'B2B', %w( [C,assert]
  when run_cyber_dojo_sh does not complete within max_seconds
  and does not produce output
  then stdout is empty,
  and the colour is 'timed_out'
  ) do
    named_args = {
      changed: { 'hiker.c' => file(quiet_infinite_loop) },
      max_seconds: 2
    }
    with_captured_log {
      run_cyber_dojo_sh(named_args)
    }
    assert_timed_out
    assert_stdout ''
    assert_stderr ''
    assert_timed_out
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '4D7', %w( [C,assert]
  when run_cyber_dojo_sh does not complete in max_seconds
  and produces output
  then stdout is not empty,
  and the colour is 'timed_out'
  ) do
    named_args = {
      changed: { 'hiker.c' => file(loud_infinite_loop) },
      max_seconds: 2
    }
    with_captured_log {
      run_cyber_dojo_sh(named_args)
    }
    assert_timed_out
    refute_stdout ''
    assert_timed_out
  end

  private # = = = = = = = = = = = = = = = = = = = = = =

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
        for(;;)
            puts("Hello");
        return 6 * 7;
    }
    SOURCE
  end

end
