# frozen_string_literal: true
require_relative 'test_base'

class FeatureTimedOutTest < TestBase

  def self.id58_prefix
    '9E9'
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test 'Q3e', %w(
  runner injects an env-var called POD_NAME
  into the container with the value of its HOSTNAME
  and this is written to the log on a timeout
  ) do
    hostname = ENV['HOSTNAME']
    ENV['HOSTNAME'] = stub_hostname = 'runner-qs99r'
    run_cyber_dojo_sh(
      max_seconds: 2,
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
    )
    assert_timed_out
    assert log.include?("POD_NAME:#{stub_hostname}"), log
  ensure
    ENV['HOSTNAME'] = hostname
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test 'B2A', %w(
  when cyber-dojo.sh modifies files in /sandbox,
  and has an infinite loop,
  then none of the /sandbox modifications are seen,
  and the colour is set to the empty string
  ) do
    run_cyber_dojo_sh(
      max_seconds: 2,
      changed: { 'cyber-dojo.sh' =>
        <<~'SOURCE'
        rm /sandbox/hiker.c
        mkdir -p /sandbox/a/b
        printf xxx > /sandbox/a/b/xxx.txt
        while true; do :; done
        SOURCE
      }
    )
    assert_deleted([]) # ['hiker.c']
    assert_created({}) # {'a/b/xxx.txt' => intact('xxx')}
    assert_changed({})
    assert_equal '', colour
  end

  # - - - - - - - - - - - - - - - - -

  c_assert_test 'B2B', %w(
  when cyber-dojo.sh has an infinite loop,
  which does not write to stdout,
  it times-out after max_seconds.
  ) do
    run_cyber_dojo_sh(
      max_seconds: 2,
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
    )
    assert_timed_out
    assert stdout.empty?, stdout
    assert stderr.empty?, stderr
    assert log.include?("Timeout::Error\n")
    assert log.include?("execution expired\n")
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  c_assert_test 'B2C', %w(
  when cyber-dojo.sh has an infinite loop,
  which writes to stdout,
  it times-out after max_seconds,
  and some of stdout is retreived.
  ) do
    run_cyber_dojo_sh(
      max_seconds: 2,
      changed: { 'hiker.c' =>
        <<~'SOURCE'
        #include "hiker.h"
        #include <stdio.h>
        int answer(void)
        {
            for(;;)
                puts("Hello");
            return 6 * 7;
        }
        SOURCE
      }
    )
    assert_timed_out
    refute stdout.empty?, stdout
    assert stderr.empty?, stderr
    assert log.include?("Timeout::Error\n")
    assert log.include?("execution expired\n")
  end

end
