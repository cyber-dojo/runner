require_relative '../../src/all_avatars_names'
require_relative 'test_base'

class MultiOSTest < TestBase

  def self.hex_prefix
    '3759D'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def self.os_test(hex_suffix, *lines, &test_block)
    alpine_lines = ['[Alpine]'] + lines
    test(hex_suffix+'0', *alpine_lines, &test_block)
    ubuntu_lines = ['[Ubuntu]'] + lines
    test(hex_suffix+'1', *ubuntu_lines, &test_block)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test 'C3A',
  'invalid avatar_name raises' do
    in_kata { assert_invalid_avatar_name_raises }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  os_test '8A3',
  'in-container tests' do
    in_kata_as(salmon) {
      assert_run_is_initially_red
      assert_pid_1_is_running_init_process
      assert_time_stamp_microseconds_granularity
      assert_env_vars_exist
      assert_avatar_users_exist
      assert_cyber_dojo_group_exists
      assert_avatar_has_home
      assert_avatar_sandbox_properties
      assert_starting_files_properties
      assert_ulimits
      assert_baseline_speed_test
      # these two create new files
      assert_files_can_be_in_sub_dirs_of_sandbox
      assert_files_can_be_in_sub_sub_dirs_of_sandbox
    }
  end

  private

  def assert_invalid_avatar_name_raises
    error = assert_raises(ArgumentError) {
      run_cyber_dojo_sh({ avatar_name:'polaroid' })
    }
    assert_equal 'avatar_name:invalid', error.message
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_run_is_initially_red
    run_cyber_dojo_sh
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_pid_1_is_running_init_process
    cmd = 'cat /proc/1/cmdline'
    proc1 = assert_cyber_dojo_sh(cmd).strip
    # odd, but there _is_ an embedded nul-character
    expected = '/dev/init' + 0.chr + '--'
    assert proc1.start_with?(expected), proc1
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_env_vars_exist
    cmd = 'printenv CYBER_DOJO_KATA_ID'
    env_kata_id     = assert_cyber_dojo_sh(cmd).strip
    cmd = 'printenv CYBER_DOJO_AVATAR_NAME'
    env_avatar_name = assert_cyber_dojo_sh(cmd).strip
    cmd = 'printenv CYBER_DOJO_SANDBOX'
    env_sandbox_dir = assert_cyber_dojo_sh(cmd).strip
    cmd = 'printenv CYBER_DOJO_RUNNER'
    env_runner      = assert_cyber_dojo_sh(cmd).strip

    assert_equal kata_id, env_kata_id
    assert_equal avatar_name, env_avatar_name
    assert_equal sandbox_dir, env_sandbox_dir
    assert_equal 'stateless', env_runner
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  include AllAvatarsNames

  def assert_avatar_users_exist
    etc_passwd = assert_cyber_dojo_sh 'cat /etc/passwd'
    all_avatars_names.each do |name|
      assert etc_passwd.include?(user_id.to_s),
        "#{name}:#{user_id}:#{etc_passwd}:#{image_name}"
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_group_exists
    stdout = assert_cyber_dojo_sh("getent group #{group}").strip
    entries = stdout.split(':')  # cyber-dojo:x:5000
    assert_equal group, entries[0], stdout
    assert_equal group_id, entries[2].to_i, stdout
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_avatar_has_home
    home = assert_cyber_dojo_sh('printenv HOME').strip
    assert_equal home_dir, home

    cd_home_pwd = assert_cyber_dojo_sh('cd ~ && pwd').strip
    assert_equal home_dir, cd_home_pwd
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_avatar_sandbox_properties
    assert_cyber_dojo_sh "[ -d #{sandbox_dir} ]" # sandbox exists

    ls = assert_cyber_dojo_sh "ls -A #{sandbox_dir}"
    refute_equal '', ls # sandbox is not empty

    stat_uid   = assert_cyber_dojo_sh("stat -c '%u' #{sandbox_dir}").strip.to_i
    stat_gid   = assert_cyber_dojo_sh("stat -c '%g' #{sandbox_dir}").strip.to_i
    stat_perms = assert_cyber_dojo_sh("stat -c '%A' #{sandbox_dir}").strip

    assert_equal user_id, stat_uid, 'stat <user>'
    assert_equal group_id, stat_gid, 'stat <gid>'
    assert_equal 'drwxr-xr-x', stat_perms, 'stat <permissions>'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_starting_files_properties
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => ls_cmd }
    })
    assert_colour 'amber' # doing an ls
    assert_stderr ''
    ls_stdout = stdout
    ls_files = ls_parse(ls_stdout)
    assert_equal starting_files.keys.sort, ls_files.keys.sort
    starting_files.each do |filename,content|
      if filename == 'cyber-dojo.sh'
        content = ls_cmd
      end
      assert_equal_atts(filename, '-rw-r--r--', user_id, group, content.length, ls_files)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_ulimits
    etc_issue = assert_cyber_dojo_sh('cat /etc/issue')
    lines = assert_cyber_dojo_sh('ulimit -a').split("\n")

    assert_equal   0, ulimit(lines, :core_size,  etc_issue)
    assert_equal 128, ulimit(lines, :file_locks, etc_issue)
    assert_equal 128, ulimit(lines, :no_files,   etc_issue)
    assert_equal 128, ulimit(lines, :processes,  etc_issue)

    kb = 1024
    mb = 1024 * kb
    gb = 1024 * mb

    expected_max_data_size  =  4 * gb / kb
    expected_max_file_size  = 16 * mb / (block_size = 512)
    expected_max_stack_size =  8 * mb / kb

    actual_max_data_size  = ulimit(lines, :data_size,  etc_issue)
    actual_max_file_size  = ulimit(lines, :file_size,  etc_issue)
    actual_max_stack_size = ulimit(lines, :stack_size, etc_issue)

    assert_equal expected_max_data_size,  actual_max_data_size
    assert_equal expected_max_file_size,  actual_max_file_size
    assert_equal expected_max_stack_size, actual_max_stack_size
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def ulimit(lines, key, etc_issue)
    table = {             # alpine,                       ubuntu
      :core_size  => [ '-c: core file size (blocks)', 'coredump(blocks)'],
      :data_size  => [ '-d: data seg size (kb)',      'data(kbytes)'    ],
      :file_locks => [ '-w: locks',                   'locks'           ],
      :file_size  => [ '-f: file size (blocks)',      'file(blocks)'    ],
      :no_files   => [ '-n: file descriptors',        'nofiles'         ],
      :processes  => [ '-p: processes',               'process'         ],
      :stack_size => [ '-s: stack size (kb)',         'stack(kbytes)'   ],
    }
    row = table[key]
    diagnostic = "no ulimit table entry for #{key}"
    refute_nil row, diagnostic
    if etc_issue.include? 'Alpine'
      txt = row[0]
    end
    if etc_issue.include? 'Ubuntu'
      txt = row[1]
    end
    line = lines.detect { |limit| limit.start_with? txt }
    line.split[-1].to_i
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_baseline_speed_test
    timings = []
    (1..5).each do
      started_at = Time.now
      assert_cyber_dojo_sh('true')
      stopped_at = Time.now
      diff = Time.at(stopped_at - started_at).utc
      secs = diff.strftime("%S").to_i
      millisecs = diff.strftime("%L").to_i
      timings << (secs * 1000 + millisecs)
    end
    mean = timings.reduce(0, :+) / timings.size
    max = (ENV['TRAVIS'] == 'true') ? 800 : 500
    assert mean < max, "mean=#{mean}, max=#{max}"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_files_can_be_in_sub_dirs_of_sandbox
    sub_dir = 'z'
    filename = 'hello.txt'
    content = 'the boy stood on the burning deck'
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => "cd #{sub_dir} && #{ls_cmd}" },
          new_files: { "#{sub_dir}/#{filename}" => content }
    })
    ls_files = ls_parse(stdout)
    assert_equal_atts(filename, '-rw-r--r--', user_id, group, content.length, ls_files)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_files_can_be_in_sub_sub_dirs_of_sandbox
    sub_sub_dir = 'a/b'
    filename = 'goodbye.txt'
    content = 'goodbye cruel world'
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => "cd #{sub_sub_dir} && #{ls_cmd}" },
          new_files: { "#{sub_sub_dir}/#{filename}" => content }
    })
    ls_files = ls_parse(stdout)
    assert_equal_atts(filename, '-rw-r--r--', user_id, group, content.length, ls_files)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_time_stamp_microseconds_granularity
    # On _default_ Alpine date-time file-stamps are to the second granularity.
    # In other words, the microseconds value is always '000000000'.
    # Make sure the tar-piped files have fixed this.

    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => ls_cmd }
    })
    count = 0
    ls_parse(stdout).each do |filename,atts|
      count += 1
      refute_nil atts, filename
      stamp = atts[:time_stamp] # eg '07:03:14.835233538'
      microsecs = stamp.split((/[\:\.]/))[-1]
      assert_equal 9, microsecs.length
      refute_equal '0'*9, microsecs
    end
    assert_equal 5, count
  end

  private

  def assert_equal_atts(filename, permissions, user, group, size, ls_files)
    atts = ls_files[filename]
    refute_nil atts, filename
    diagnostic = { filename => atts }
    assert_equal user,  atts[:user ], diagnostic
    assert_equal group, atts[:group], diagnostic
    assert_equal size,  atts[:size ], diagnostic
    assert_equal permissions, atts[:permissions], diagnostic
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def ls_parse(ls_stdout)
    Hash[ls_stdout.split("\n").collect { |line|
      attr = line.split
      [attr[0], { # filename
        permissions: attr[1],
               user: attr[2].to_i,
              group: attr[3],
               size: attr[4].to_i,
         time_stamp: attr[6],
      }]
    }]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def ls_cmd;
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
