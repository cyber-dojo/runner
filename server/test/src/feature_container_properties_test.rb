require_relative 'test_base'

class ContainerPropertiesTest < TestBase

  def self.hex_prefix
    '3A8'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '8A3',
  'container environment properties' do
    in_kata {
      assert_pid_1_is_running_init_process
      assert_cyber_dojo_runs_in_bash
      assert_time_stamp_microseconds_granularity
      assert_env_vars_exist
      assert_sandbox_user_exists
      assert_sandbox_group_exists
      assert_sandbox_user_has_home
      assert_sandbox_dir_properties
      assert_starting_files_properties
      assert_ulimits
    }
  end

  private # = = = = = = = = = = = = = = = = = = = = = =

  def assert_pid_1_is_running_init_process
    cmd = 'cat /proc/1/cmdline'
    proc1 = assert_cyber_dojo_sh(cmd)
    # odd, but there _is_ an embedded nul-character
    expected = '/dev/init' + 0.chr + '--'
    assert proc1.start_with?(expected), proc1
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_runs_in_bash
    assert_equal '/bin/bash', cyber_dojo_sh_shell
  end

  def cyber_dojo_sh_shell
    cmd = 'echo ${SHELL}'
    assert_cyber_dojo_sh(cmd)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_env_vars_exist
    assert_equal  image_name, env_var('IMAGE_NAME')
    assert_equal          id, env_var('ID')
    assert_equal 'stateless', env_var('RUNNER')
    assert_equal sandbox_dir, env_var('SANDBOX')
  end

  def env_var(name)
    cmd = "printenv CYBER_DOJO_#{name}"
    assert_cyber_dojo_sh(cmd)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_sandbox_user_exists
    etc_passwd = assert_cyber_dojo_sh 'cat /etc/passwd'
    name = 'sandbox'
    diagnostic = "#{name}:#{uid}:#{etc_passwd}:#{image_name}"
    assert etc_passwd.include?(uid.to_s), diagnostic
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_sandbox_group_exists
    assert_cyber_dojo_sh("getent group #{group}")
    entries = stdout.split(':')  # sandbox:x:51966
    assert_equal group, entries[0], stdout
    assert_equal   gid, entries[2].to_i, stdout
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_sandbox_user_has_home
    assert_equal home_dir, assert_cyber_dojo_sh('printenv HOME')
    assert_equal home_dir, assert_cyber_dojo_sh('cd ~ && pwd')
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_sandbox_dir_properties
    assert_cyber_dojo_sh "[ -d #{sandbox_dir} ]" # sandbox exists
    refute_equal '', assert_cyber_dojo_sh("ls -A #{sandbox_dir}")
    assert_equal     uid.to_s, stat_sandbox_dir('u'), 'stat <uid>  sandbox_dir'
    assert_equal     gid.to_s, stat_sandbox_dir('g'), 'stat <gid>  sandbox_dir'
    assert_equal 'drwxr-xr-x', stat_sandbox_dir('A'), 'stat <perm> sandbox_dir'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def stat_sandbox_dir(ch)
    assert_cyber_dojo_sh("stat -c '%#{ch}' #{sandbox_dir}")
  end

  def home_dir
    "/home/sandbox"
  end

  def sandbox_dir
    '/sandbox'
  end

  def uid
    41966
  end

  def gid
    51966
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_starting_files_properties
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => stat_cmd }
    })
    assert_equal '', stderr
    assert_equal starting_files.keys.sort, stdout_stats.keys.sort
    starting_files.each do |filename, content|
      if filename == 'cyber-dojo.sh'
        content = stat_cmd
      end
      assert_stats(filename, '-rw-r--r--', content.length)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_ulimits
    assert_cyber_dojo_sh("sh -c 'ulimit -a'")

    expected_max_data_size  =  clang? ? 0 : 4 * GB / KB
    expected_max_file_size  = 16 * MB / (block_size = 512)
    expected_max_stack_size =  8 * MB / KB

    assert_equal expected_max_data_size,  ulimit(:data_size)
    assert_equal expected_max_file_size,  ulimit(:file_size)
    assert_equal expected_max_stack_size, ulimit(:stack_size)
    assert_equal 0,                       ulimit(:core_size)
    assert_equal 128,                     ulimit(:file_locks)
    assert_equal 256,                     ulimit(:no_files)
    assert_equal 128,                     ulimit(:processes)
  end

  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB

  def clang?
    image_name.start_with?('cyberdojofoundation/clang')
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def ulimit(key)
    table = {             # alpine (sh),               ubuntu
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
    if os == :Alpine
      txt = row[0]
    end
    if os == :Ubuntu
      txt = row[1]
    end
    line = stdout.lines.detect { |line| line.start_with?(txt) }
    line.split[-1].to_i
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_time_stamp_microseconds_granularity
    # On _default_ Alpine date-time file-stamps are to
    # the second granularity. In other words, the
    # microseconds value is always '000000000'.
    # Make sure the tar-piped files have fixed this.
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => stat_cmd }
    })
    count = 0
    stdout_stats.each do |filename,atts|
      count += 1
      refute_nil atts, filename
      stamp = atts[:time] # eg '07:03:14.835233538'
      microsecs = stamp.split(/[\:\.]/)[-1]
      assert_equal 9, microsecs.length
      refute_equal '0'*9, microsecs
    end
    assert count > 0, count
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_stats(filename, permissions, size)
    stats = stdout_stats[filename]
    refute_nil stats, filename
    diagnostic = { filename => stats }
    assert_equal permissions, stats[:permissions], diagnostic
    assert_equal         uid, stats[:uid        ], diagnostic
    assert_equal       group, stats[:group      ], diagnostic
    assert_equal        size, stats[:size       ], diagnostic
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
               time: attr[6],
      }]
    }]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def stat_cmd
    # Works on Ubuntu and Alpine
    'stat -c "%n %A %u %G %s %y" *'
    # hiker.h  -rw-r--r--  40045  cyber-dojo 136  2016-06-05 07:03:14.539952547
    # |        |           |      |          |    |          |
    # filename permissions uid    group      size date       time
    # 0        1           2      3          4    5          6

    # Stat
    #  %z == time of last status change
    #  %y == time of last data modification <<=====
    #  %x == time of last access
    #  %w == time of file birth
  end

end
