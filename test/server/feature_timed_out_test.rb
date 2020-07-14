# frozen_string_literal: true
require_relative 'test_base'

class FeatureTimedOutTest < TestBase

  def self.id58_prefix
    '9E9'
  end

  def id58_setup
    context.puller.add(image_name)
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test 'B2A', %w(
  when cyber-dojo.sh has an infinite loop,
  it times out after max_seconds,
  and modified files in /sandbox are not seen,
  and anything written to stdout|stderr is not seen,
  and the colour is set to the empty string
  ) do
    run_cyber_dojo_sh(
      max_seconds: 2,
      changed: { 'cyber-dojo.sh' =>
        <<~'SOURCE'
        echo hello
        2>&1 echo bonjour
        rm /sandbox/hiker.c
        mkdir -p /sandbox/a/b
        printf xxx > /sandbox/a/b/xxx.txt
        while true; do :; done
        SOURCE
      }
    )
    assert timed_out?, pretty_result(:timed_out)
    assert_equal '', stdout, :stdout_empty
    assert_equal '', stderr, :stderr_empty
    assert_deleted([]) # ['hiker.c']
    assert_created({}) # {'a/b/xxx.txt' => intact('xxx')}
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test 'B2C', %w(
  when a program cyber-dojo.sh runs has an infinite loop,
  it times out after max_seconds,
  and modified files in /sandbox, are not seen,
  and anything written to stdout|stderr is not seen,
  and the colour is set to the empty string
  ) do
    run_cyber_dojo_sh(
      max_seconds: 2,
      changed: { 'hiker.c' =>
        <<~'SOURCE'
        #include "hiker.h"
        #include <stdio.h>
        int answer(void)
        {
            FILE * f = fopen("/sandbox/hello.txt", "w");
            fputs("Hello\n", f);
            fclose(f);
            fputs("Hello\n", stdout);
            for(;;)
                ;
            return 6 * 7;
        }
        SOURCE
      }
    )

    assert timed_out?, pretty_result(:timed_out)
    assert_equal '', stdout, :stdout_empty
    assert_equal '', stderr, :stderr_empty
    assert_deleted([])
    assert_created({}) # {'hello.txt' => intact("Hello\n")}
    assert_changed({})
  end

end
