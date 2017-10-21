require_relative '../../src/all_avatars_names'

module OsHelper

  module_function

  def kata_id_env_vars_test
    env = {}
    cmd = 'printenv CYBER_DOJO_KATA_ID'
    env[:kata_id]     = assert_cyber_dojo_sh(cmd).strip
    cmd = 'printenv CYBER_DOJO_AVATAR_NAME'
    env[:avatar_name] = assert_cyber_dojo_sh(cmd).strip
    cmd = 'printenv CYBER_DOJO_SANDBOX'
    env[:sandbox]     = assert_cyber_dojo_sh(cmd).strip

    assert_equal kata_id, env[:kata_id]
    assert_equal default_avatar_name, env[:avatar_name]
    assert_equal runner.sandbox_dir(default_avatar_name), env[:sandbox]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  include AllAvatarsNames

  def assert_avatar_users_exist
    etc_passwd = assert_cyber_dojo_sh 'cat /etc/passwd'
    all_avatars_names.each do |name|
      uid = runner.user_id(name).to_s
      assert etc_passwd.include?(uid),
        "#{name}:#{uid}\n\n#{etc_passwd}\n\n#{image_name}"
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_group_exists
    stdout = assert_cyber_dojo_sh("getent group #{runner.group}").strip
    entries = stdout.split(':')  # cyber-dojo:x:5000
    ent = {
      group:entries[0],
        gid:entries[2].to_i
    }
    assert_equal runner.group, ent[:group], stdout
    assert_equal runner.gid,   ent[:gid],   stdout
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def new_avatar_home_test
    home = assert_cyber_dojo_sh('printenv HOME').strip
    assert_equal runner.home_dir(default_avatar_name), home

    cd_home_pwd = assert_cyber_dojo_sh('cd ~ && pwd').strip
    assert_equal runner.home_dir(default_avatar_name), cd_home_pwd
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def new_avatar_sandbox_setup_test
    sandbox = runner.sandbox_dir(default_avatar_name)
    assert_cyber_dojo_sh "[ -d #{sandbox} ]" # sandbox exists

    ls = assert_cyber_dojo_sh "ls -A #{sandbox}"
    refute_equal '', ls # sandbox is not empty

    stat = {}
    stat[:user]  = assert_cyber_dojo_sh("stat -c '%u' #{sandbox}").strip.to_i
    stat[:gid]   = assert_cyber_dojo_sh("stat -c '%g' #{sandbox}").strip.to_i
    stat[:perms] = assert_cyber_dojo_sh("stat -c '%A' #{sandbox}").strip

    assert_equal runner.user_id(default_avatar_name), stat[:user]
    assert_equal runner.gid, stat[:gid]
    assert_equal 'drwxr-xr-x', stat[:perms]
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def new_avatar_starting_files_test
    run4({ avatar_name:'lion', visible_files:ls_starting_files })
    assert_colour 'amber' # ???
    assert_stderr ''
    ls_stdout = stdout
    ls_files = ls_parse(ls_stdout)
    assert_equal ls_starting_files.keys.sort, ls_files.keys.sort
    uid = runner.user_id('lion')
    group = runner.group
    assert_equal_atts('empty.txt',     '-rw-r--r--', uid, group,  0, ls_files)
    assert_equal_atts('cyber-dojo.sh', '-rw-r--r--', uid, group, 29, ls_files)
    assert_equal_atts('hello.txt',     '-rw-r--r--', uid, group, 11, ls_files)
    assert_equal_atts('hello.sh',      '-rw-r--r--', uid, group, 16, ls_files)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def ulimit_test
    etc_issue = assert_cyber_dojo_sh('cat /etc/issue')
    lines = assert_cyber_dojo_sh('ulimit -a').split("\n")
    assert_equal  128, ulimit(lines, :max_processes,  etc_issue)
    assert_equal    0, ulimit(lines, :max_core_size,  etc_issue)
    assert_equal  128, ulimit(lines, :max_no_files,   etc_issue)
    assert_equal 4096, ulimit(lines, :max_stack_size, etc_issue)  # in KB
    assert_equal   10, ulimit(lines, :max_cpu_time,   etc_issue)  # in seconds
    assert_equal  128, ulimit(lines, :max_file_locks, etc_issue)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def ulimit(lines, key, etc_issue)
    table = {             # alpine,                       ubuntu
      :max_processes  => [ '-p: processes',               'process'         ],
      :max_core_size  => [ '-c: core file size (blocks)', 'coredump(blocks)'],
      :max_no_files   => [ '-n: file descriptors',        'nofiles'         ],
      :max_stack_size => [ '-s: stack size (kb)',         'stack(kbytes)'   ],
      :max_cpu_time   => [ '-t: cpu time (seconds)',      'time(seconds)'   ],
      :max_file_locks => [ '-w: locks',                   'locks'           ],
    }
    if alpine?(etc_issue); txt = table[key][0]; end
    if ubuntu?(etc_issue); txt = table[key][1]; end
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

  private

  def alpine?(etc_issue)
    etc_issue.include? 'Alpine'
  end

  def ubuntu?(etc_issue)
    etc_issue.include? 'Ubuntu'
  end

end
