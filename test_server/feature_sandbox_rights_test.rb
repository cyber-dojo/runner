require_relative 'test_base'

class SandboxRightsTest < TestBase

  def self.hex_prefix
    'D8D'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '296',
  'new sub-dirs are owned by sandbox' do
    assert_dirs_can_be_created_in_sandbox_sub_dir
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '8A4',
  'files can be created in sandbox sub-dirs' do
    assert_files_can_be_created_in_sandbox_sub_dir('s1')
    assert_files_can_be_created_in_sandbox_sub_dir('s1/s2')
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '12B',
  %w( files can be deleted from sandbox sub-dir ) do
    assert_files_can_be_deleted_from_sandbox_sub_dir('d1')
    assert_files_can_be_deleted_from_sandbox_sub_dir('d1/d2')
  end

  private # = = = = = = = = = = = = = = = = = = = = = =

  def assert_dirs_can_be_created_in_sandbox_sub_dir
    sub_dir = 'z'
    filename = 'hello.txt'
    content = 'the boy stood on the burning deck'
    run_cyber_dojo_sh({
      changed: { 'cyber-dojo.sh' => stat_cmd },
      created: { "#{sub_dir}/#{filename}" => content }
    })
    assert_stats(sub_dir, 'drwxr-xr-x', 60)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_files_can_be_created_in_sandbox_sub_dir(sub_dir)
    filename = 'hello.txt'
    content = 'the boy stood on the burning deck'
    run_cyber_dojo_sh({
      changed: { 'cyber-dojo.sh' => "cd #{sub_dir} && #{stat_cmd}" },
      created: { "#{sub_dir}/#{filename}" => content }
    })
    assert_stats(filename, '-rw-r--r--', content.length)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_files_can_be_deleted_from_sandbox_sub_dir(sub_dir)
    filename = 'goodbye.txt'
    content = 'goodbye, world'
    run_cyber_dojo_sh({
      changed: { 'cyber-dojo.sh' => "cd #{sub_dir} && #{stat_cmd}" },
      created: { "#{sub_dir}/#{filename}" => content }
    })
    filenames = stdout_stats.keys
    assert filenames.include?(filename)
    run_cyber_dojo_sh({
      deleted: [ "#{sub_dir}/#{filename}" ]
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

end
