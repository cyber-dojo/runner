require_relative 'test_base'

class SandboxRightsTest < TestBase

  def self.hex_prefix
    'D8D'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '8A4',
  'files can be created in sandbox sub-dirs' do
    in_kata {
      assert_files_can_be_created_in_sandbox_sub_dir
    }
    in_kata {
      assert_files_can_be_created_in_sandbox_sub_sub_dir
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '12B',
  %w( files can be deleted from sandbox sub-dir ) do
    in_kata {
      assert_files_can_be_deleted_from_sandbox_sub_dir
    }
    in_kata {
      assert_files_can_be_deleted_from_sandbox_sub_sub_dir
    }
  end

  private # = = = = = = = = = = = = = = = = = = = = = =

  def assert_files_can_be_created_in_sandbox_sub_dir
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

  def assert_files_can_be_created_in_sandbox_sub_sub_dir
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

  def assert_files_can_be_deleted_from_sandbox_sub_dir
    sub_dir = 'a'
    filename = 'goodbye.txt'
    content = 'goodbye, world'
    run_cyber_dojo_sh({
          new_files: { "#{sub_dir}/#{filename}" => content },
      changed_files: { 'cyber-dojo.sh' => "cd #{sub_dir} && #{stat_cmd}" }
    })
    filenames = stdout_stats.keys
    assert filenames.include?(filename)
    run_cyber_dojo_sh({
      deleted_files: { "#{sub_dir}/#{filename}" => content }
    })
    filenames = stdout_stats.keys
    refute filenames.include?(filename)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_files_can_be_deleted_from_sandbox_sub_sub_dir
    sub_sub_dir = 'a/b/c'
    filename = 'goodbye.txt'
    content = 'goodbye, world'
    run_cyber_dojo_sh({
          new_files: { "#{sub_sub_dir}/#{filename}" => content },
      changed_files: { 'cyber-dojo.sh' => "cd #{sub_sub_dir} && #{stat_cmd}" }
    })
    filenames = stdout_stats.keys
    assert filenames.include?(filename)
    run_cyber_dojo_sh({
      deleted_files: { "#{sub_sub_dir}/#{filename}" => content }
    })
    filenames = stdout_stats.keys
    refute filenames.include?(filename)
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

end