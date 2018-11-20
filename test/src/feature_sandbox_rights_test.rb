require_relative 'test_base'

class SandboxRightsTest < TestBase

  def self.hex_prefix
    'D8D'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '296',
  'new sub-dirs are owned by sandbox' do
    in_kata {
      assert_dirs_can_be_created_in_sandbox_sub_dir
    }
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '8A4',
  'files can be created in sandbox sub-dirs' do
    in_kata {
      assert_files_can_be_created_in_sandbox_sub_dir('s1')
    }
    in_kata {
      assert_files_can_be_created_in_sandbox_sub_dir('s1/s2')
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '12B',
  %w( files can be deleted from sandbox sub-dir ) do
    in_kata {
      assert_files_can_be_deleted_from_sandbox_sub_dir('d1')
    }
    in_kata {
      assert_files_can_be_deleted_from_sandbox_sub_dir('d1/d2')
    }
  end

  private # = = = = = = = = = = = = = = = = = = = = = =

  def assert_dirs_can_be_created_in_sandbox_sub_dir
    sub_dir = 'z'
    filename = 'hello.txt'
    content = 'the boy stood on the burning deck'
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => file(stat_cmd) },
          new_files: { "#{sub_dir}/#{filename}" => file(content) }
    })
    assert_stats(sub_dir, 'drwxr-xr-x', 4096)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_files_can_be_created_in_sandbox_sub_dir(sub_dir)
    filename = 'hello.txt'
    content = 'the boy stood on the burning deck'
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => file("cd #{sub_dir} && #{stat_cmd}") },
          new_files: { "#{sub_dir}/#{filename}" => file(content) }
    })
    assert_stats(filename, '-rw-r--r--', content.length)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_files_can_be_deleted_from_sandbox_sub_dir(sub_dir)
    filename = 'goodbye.txt'
    content = 'goodbye, world'
    run_cyber_dojo_sh({
          new_files: { "#{sub_dir}/#{filename}" => file(content) },
      changed_files: { 'cyber-dojo.sh' => file("cd #{sub_dir} && #{stat_cmd}") }
    })
    filenames = stdout_stats.keys
    assert filenames.include?(filename)
    run_cyber_dojo_sh({
      deleted_files: { "#{sub_dir}/#{filename}" => file(content) }
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
      [attr[0], {         # filename eg hiker.h
        permissions: attr[1],      # eg -rwxr--r--
                uid: attr[2].to_i, # eg 40045
              group: attr[3],      # eg cyber-dojo
               size: attr[4].to_i, # eg 136
         time_stamp: attr[6],      # eg 07:03:14.539952547
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
