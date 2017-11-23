require_relative 'test_base'

class RunCyberDojoShTest < TestBase

  def self.hex_prefix
    'D8D88'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '4CC',
  %w( invalid avatar_name raises ) do
    in_kata_as(salmon) {
      error = assert_raises(ArgumentError) {
        run_cyber_dojo_sh({ avatar_name: 'waterbottle' })
      }
      assert_equal 'avatar_name:invalid', error.message
    }
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '8A5',
  %w( when run_cyber_dojo_sh completes within max_seconds
      then timed_out is false
  ) do
    in_kata_as(salmon) {
      run_cyber_dojo_sh
    }
    refute_timed_out
    assert_status 2
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - -

  test 'B2B', %w( [Alpine]
  when run_cyber_dojo_sh does not complete within max_seconds
  and does not produce output
  then stdout is empty,
  and timed_out is true
  ) do
    in_kata_as(salmon) {
      named_args = {
        changed_files: { 'hiker.c' => quiet_infinite_loop },
          max_seconds: 2
      }
      run_cyber_dojo_sh(named_args)
    }
    assert_timed_out
    assert_stdout ''
    assert_stderr ''
    assert_timed_out
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '4D7', %w( [Alpine]
  when run_cyber_dojo_sh does not complete in max_seconds
  and produces output
  then stdout is not empty,
  and timed_out is true
  ) do
    in_kata_as(salmon) {
      named_args = {
        changed_files: { 'hiker.c' => loud_infinite_loop },
          max_seconds: 2
      }
      run_cyber_dojo_sh(named_args)
    }
    assert_timed_out
    refute_stdout ''
    assert_timed_out
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '8A4',
  'files can be created in sandbox sub-dirs' do
    in_kata_as(salmon) {
      assert_files_can_be_in_sub_dirs_of_sandbox
      assert_files_can_be_in_sub_sub_dirs_of_sandbox
    }
  end

  private

  def assert_files_can_be_in_sub_dirs_of_sandbox
    sub_dir = 'z'
    filename = 'hello.txt'
    content = 'the boy stood on the burning deck'
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => "cd #{sub_dir} && #{stat_cmd}" },
          new_files: { "#{sub_dir}/#{filename}" => content }
    })
    assert_stats(filename, '-rw-r--r--', content.length)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_files_can_be_in_sub_sub_dirs_of_sandbox
    sub_sub_dir = 'a/b'
    filename = 'goodbye.txt'
    content = 'goodbye cruel world'
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => "cd #{sub_sub_dir} && #{stat_cmd}" },
          new_files: { "#{sub_sub_dir}/#{filename}" => content }
    })
    assert_stats(filename, '-rw-r--r--', content.length)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_stats(filename, permissions, size)
    stats = stdout_stats[filename]
    refute_nil stats, filename
    diagnostic = { filename => stats }
    assert_equal permissions, stats[:permissions], diagnostic
    assert_equal uid, stats[:uid ], diagnostic
    assert_equal group, stats[:group], diagnostic
    assert_equal size, stats[:size ], diagnostic
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def stdout_stats
    Hash[stdout.lines.collect { |line|
      attr = line.split
      [attr[0], { # filename
        permissions: attr[1],
                uid: attr[2].to_i,
              group: attr[3],
               size: attr[4].to_i,
         time_stamp: attr[6],
      }]
    }]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def stat_cmd;
    # Works on Ubuntu and Alpine
    'stat -c "%n %A %u %G %s %y" *'
    # hiker.h  -rw-r--r--  40045  cyber-dojo 136  2016-06-05 07:03:14.539952547
    # |        |           |      |          |    |          |
    # filename permissions user   group      size date       time
    # 0        1           2      3          4    5          6

    # Stat
    #  %z == time of last status change
    #  %y == time of last data modification <<=====
    #  %x == time of last access
    #  %w == time of file birth
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
        for(;;)
            puts("Hello");
        return 6 * 7;
    }
    SOURCE
  end

end