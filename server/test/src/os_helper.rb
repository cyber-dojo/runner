require_relative '../../src/all_avatars_names'

module OsHelper

  module_function

  def invalid_avatar_name_raises
    error = assert_raises(ArgumentError) {
      run_cyber_dojo_sh({ avatar_name:'polaroid' })
    }
    assert_equal 'avatar_name:invalid', error.message
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def run_is_initially_red
    run_cyber_dojo_sh
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def pid_1_init_process_test
    cmd = 'cat /proc/1/cmdline'
    proc1 = assert_cyber_dojo_sh(cmd).strip
    # odd, but there _is_ an embedded nul-character
    expected = '/dev/init' + 0.chr + '--'
    assert proc1.start_with?(expected), proc1
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def kata_id_env_vars_test
    env = {}
    cmd = 'printenv CYBER_DOJO_KATA_ID'
    env[:kata_id]     = assert_cyber_dojo_sh(cmd).strip
    cmd = 'printenv CYBER_DOJO_AVATAR_NAME'
    env[:avatar_name] = assert_cyber_dojo_sh(cmd).strip
    cmd = 'printenv CYBER_DOJO_SANDBOX'
    env[:sandbox_dir] = assert_cyber_dojo_sh(cmd).strip
    cmd = 'printenv CYBER_DOJO_RUNNER'
    env[:runner]      = assert_cyber_dojo_sh(cmd).strip

    assert_equal kata_id, env[:kata_id]
    assert_equal avatar_name, env[:avatar_name]
    assert_equal sandbox_dir, env[:sandbox_dir]
    assert_equal 'stateless', env[:runner]
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
    assert_equal gid,   entries[2].to_i, stdout
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def avatar_new_home_test
    home = assert_cyber_dojo_sh('printenv HOME').strip
    assert_equal home_dir, home

    cd_home_pwd = assert_cyber_dojo_sh('cd ~ && pwd').strip
    assert_equal home_dir, cd_home_pwd
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def avatar_new_sandbox_setup_test
    assert_cyber_dojo_sh "[ -d #{sandbox_dir} ]" # sandbox exists

    ls = assert_cyber_dojo_sh "ls -A #{sandbox_dir}"
    refute_equal '', ls # sandbox is not empty

    stat = {}
    stat[:user]  = assert_cyber_dojo_sh("stat -c '%u' #{sandbox_dir}").strip.to_i
    stat[:gid]   = assert_cyber_dojo_sh("stat -c '%g' #{sandbox_dir}").strip.to_i
    stat[:perms] = assert_cyber_dojo_sh("stat -c '%A' #{sandbox_dir}").strip

    assert_equal user_id, stat[:user]
    assert_equal gid, stat[:gid]
    assert_equal 'drwxr-xr-x', stat[:perms]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def avatar_new_starting_files_test
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

  def ulimit_test
    etc_issue = assert_cyber_dojo_sh('cat /etc/issue')
    lines = assert_cyber_dojo_sh('ulimit -a').split("\n")

    assert_equal   0, ulimit(lines, :core_size,  etc_issue)
    assert_equal 128, ulimit(lines, :file_locks, etc_issue)
    assert_equal 128, ulimit(lines, :no_files,   etc_issue)
    assert_equal 128, ulimit(lines, :processes,  etc_issue)

    expected_data_size = 4 * gb / kb
    assert_equal expected_data_size,  ulimit(lines, :data_size,  etc_issue)

    expected_file_size = 16 * mb / (block_size = 512)
    assert_equal expected_file_size,  ulimit(lines, :file_size,  etc_issue)

    expected_stack_size = 8 * mb / kb
    assert_equal expected_stack_size, ulimit(lines, :stack_size, etc_issue)
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
    refute_nil row, "no ulimit table entry for #{key}"
    if alpine?(etc_issue)
      txt = row[0]
    end
    if ubuntu?(etc_issue)
      txt = row[1]
    end
    line = lines.detect { |limit| limit.start_with? txt }
    line.split[-1].to_i
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def baseline_speed_test
    millisecs = []
    (1..5).each do
      t1 = Time.now
      assert_cyber_dojo_sh('true')
      t2 = Time.now
      diff = Time.at(t2 - t1).utc
      duration = diff.strftime("%S").to_i * 1000
      duration += diff.strftime("%L").to_i
      millisecs << duration
    end
    mean = millisecs.reduce(0, :+) / millisecs.size
    max = (ENV['TRAVIS'] == 'true') ? 800 : 500
    assert mean < max, "mean=#{mean}, max=#{max}"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def files_can_be_in_sub_dirs_of_sandbox
    sub_dir = 'z'
    filename = 'hello.txt'
    content = 'the boy stood on the burning deck'
    in_kata_as(lion) {
      run_cyber_dojo_sh({
        changed_files: { 'cyber-dojo.sh' => "cd #{sub_dir} && #{ls_cmd}" },
            new_files: { "#{sub_dir}/#{filename}" => content }
      })
    }
    ls_files = ls_parse(stdout)
    assert_equal_atts(filename, '-rw-r--r--', user_id, group, content.length, ls_files)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def files_can_be_in_sub_sub_dirs_of_sandbox
    sub_sub_dir = 'a/b'
    filename = 'goodbye.txt'
    content = 'goodbye cruel world'
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        changed_files: { 'cyber-dojo.sh' => "cd #{sub_sub_dir} && #{ls_cmd}" },
            new_files: { "#{sub_sub_dir}/#{filename}" => content }
      })
    }
    ls_files = ls_parse(stdout)
    assert_equal_atts(filename, '-rw-r--r--', user_id, group, content.length, ls_files)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def files_have_time_stamp_with_microseconds_granularity
    # On _default_ Alpine date-time file-stamps are to the second granularity.
    # In other words, the microseconds value is always '000000000'.
    # Make sure the Alpine packages have been installed to fix this.
    in_kata_as(squid) {
      run_cyber_dojo_sh({
        changed_files: { 'cyber-dojo.sh' => ls_cmd }
      })
    }
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

  def alpine?(etc_issue)
    etc_issue.include? 'Alpine'
  end

  def ubuntu?(etc_issue)
    etc_issue.include? 'Ubuntu'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def kb
    1024
  end

  def mb
    kb * 1024
  end

  def gb
    mb * 1024
  end

end
