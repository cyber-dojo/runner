require_relative 'test_base'

class ApiTest < TestBase

  def self.hex_prefix
    '3759D'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # start-files image_name<->os correctness
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '8A2',
  'os-image correspondence' do
    in_kata_as(salmon) {
      etc_issue = assert_cyber_dojo_sh('cat /etc/issue')
      case os
      when :Alpine
        assert etc_issue.include? 'Alpine'
      when :Ubuntu
        assert etc_issue.include? 'Ubuntu'
      end
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # robustness
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '2F0',
  'call to non existent method becomes exception' do
    assert_exception('does_not_exist', {}.to_json)
  end

  multi_os_test '2F1',
  'call to existing method with bad json becomes exception' do
    assert_exception('does_not_exist', '{x}')
  end

  multi_os_test '2F2',
  'call to existing method with missing argument becomes exception' do
    in_kata {
      args = { image_name:image_name, kata_id:kata_id }
      assert_exception('avatar_new', args.to_json)
    }
  end

  multi_os_test '2F3',
  'call to existing method with bad argument type becomes exception' do
    in_kata_as(salmon) {
      args = {
        image_name:image_name,
        kata_id:kata_id,
        avatar_name:avatar_name,
        new_files:2, # <=====
        deleted_files:{},
        unchanged_files:{},
        changed_files:{},
        max_seconds:2
      }
      assert_exception('run_cyber_dojo_sh', args.to_json)
    }
  end

  include HttpJsonService

  def hostname
    ENV['CYBER_DOJO_RUNNER_SERVER_NAME']
  end

  def port
    ENV['CYBER_DOJO_RUNNER_SERVER_PORT']
  end

  def assert_exception(method_name, jsoned_args)
    json = http(method_name, jsoned_args) { |uri|
      Net::HTTP::Post.new(uri)
    }
    refute_nil json['exception']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # invalid arguments
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  METHOD_NAMES = [ :image_pulled?, :image_pull,
                   :kata_new, :kata_old,
                   :avatar_new, :avatar_old,
                   :run_cyber_dojo_sh ]

 INVALID_IMAGE_NAMES = [ nil, '_cantStartWithSeparator' ]

  multi_os_test 'D21',
  'all api methods raise when image_name is invalid' do
    in_kata_as(salmon) do
      METHOD_NAMES.each do |method_name|
        INVALID_IMAGE_NAMES.each do |image_name|
          error = assert_raises(StandardError, method_name.to_s) do
            self.send method_name, { image_name:image_name }
          end
          expected = "RunnerService:#{method_name}:image_name:invalid"
          assert_equal expected, error.message
        end
      end
    end
  end

  INVALID_KATA_IDS = [ nil, '675' ]

  multi_os_test '656',
  'all api methods raise when kata_id is invalid' do
    in_kata_as(salmon) do
      METHOD_NAMES.each do |method_name|
        INVALID_KATA_IDS.each do |kata_id|
          error = assert_raises(StandardError, method_name.to_s) do
            self.send method_name, { kata_id:kata_id }
          end
          expected = "RunnerService:#{method_name}:kata_id:invalid"
          assert_equal expected, error.message
        end
      end
    end
  end

  INVALID_AVATAR_NAMES = [ nil, 'sunglasses' ]

  multi_os_test 'C3A',
  'api methods raise when avatar_name is invalid' do
    in_kata_as(salmon) do
      [ :avatar_new, :avatar_old, :run_cyber_dojo_sh ].each do |method_name|
        INVALID_AVATAR_NAMES.each do |avatar_name|
          error = assert_raises(StandardError, method_name.to_s) do
            self.send method_name, { avatar_name:avatar_name }
          end
          expected = "RunnerService:#{method_name}:avatar_name:invalid"
          assert_equal expected, error.message
        end
      end
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # vanilla red-amber-green
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '3DF',
  'run with initial 6*9 == 42 is red' do
    in_kata_as(salmon) {
      run_cyber_dojo_sh
      assert red?, quad
    }
  end

  multi_os_test '3DE',
  'run with syntax error is amber' do
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        changed_files: {
          'hiker.c' => hiker_c.sub('6 * 9', '6 * 9sd')
        }
      })
      assert amber?, quad
    }
  end

  multi_os_test '3DD',
  'run with 6*7 == 42 is green' do
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        changed_files: {
          'hiker.c' => hiker_c.sub('6 * 9', '6 * 7')
        }
      })
      assert green?, quad
    }
  end

  def hiker_c
    starting_files['hiker.c']
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # timing out
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '3DC',
  'run with infinite loop times out' do
    in_kata_as(salmon) {
      from = 'return 6 * 9'
      to = "    for (;;);\n    return 6 * 7;"
      run_cyber_dojo_sh({
        changed_files: { 'hiker.c' => hiker_c.sub(from, to) },
          max_seconds: 3
      })
      assert timed_out?, quad
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # large-files
  # docker-compose.yml need a tmpfs for this to pass
  #      tmpfs: /tmp
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '3DB',
  'run with very large file is red' do
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        new_files: { 'big_file' => 'X'*1023*500 }
      })
    }
    assert red?, quad
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'ED4',
  'stdout greater than 10K is truncated' do
    # [1] fold limit is 10000 so I do two smaller folds
    five_K_plus_1 = 5*1024+1
    command = [
      'cat /dev/urandom',
      "tr -dc 'a-zA-Z0-9'",
      "fold -w #{five_K_plus_1}", # [1]
      'head -n 1'
    ].join('|')
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        changed_files: {
          'cyber-dojo.sh' => "seq 2 | xargs -I{} sh -c '#{command}'"
        }
      })
    }
    assert stdout.include? 'output truncated by cyber-dojo'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # container properties
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '8A3',
  'container environment properties' do
    in_kata_as(salmon) {
      assert_pid_1_is_running_init_process
      assert_time_stamp_microseconds_granularity
      assert_env_vars_exist
      assert_avatar_users_exist
      assert_cyber_dojo_group_exists
      assert_avatar_has_home
      assert_avatar_sandbox_properties
      assert_starting_files_properties
      assert_ulimits
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # files crud
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '8A4',
  'files can be created in sandbox sub-dirs' do
    in_kata_as(salmon) {
      assert_files_can_be_created_in_sub_dirs_of_sandbox
      assert_files_can_be_created_in_sub_sub_dirs_of_sandbox
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # baseline speed
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '8A6',
  'baseline speed' do
    in_kata_as(salmon) {
      assert_baseline_speed
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -
  # bombs
  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD5',
  'fork-bomb does not run indefinitely' do
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        changed_files: { 'hiker.c' => C_FORK_BOMB },
          max_seconds: 3
      })
      assert_timed_out_or_printed 'All tests passed'
      assert_timed_out_or_printed 'fork()'
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD6',
  'shell fork-bomb does not run indefinitely' do
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        changed_files: { 'cyber-dojo.sh' => SHELL_FORK_BOMB },
          max_seconds: 3
      })
      cant_fork = (os == :Alpine ? "can't fork" : 'Cannot fork')
      assert_timed_out_or_printed cant_fork
      assert_timed_out_or_printed 'bomb'
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'CD7',
  'file-handles quickly become exhausted' do
    in_kata_as(salmon) {
      run_cyber_dojo_sh({
        changed_files: { 'hiker.c' => FILE_HANDLE_BOMB },
          max_seconds: 3
      })
      assert seen?('All tests passed'), quad
      assert seen?('fopen() != NULL'),  quad
      assert seen?('fopen() == NULL'),  quad
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

  def assert_env_vars_exist
    assert_equal avatar_name, env_var('AVATAR_NAME')
    assert_equal  image_name, env_var('IMAGE_NAME')
    assert_equal     kata_id, env_var('KATA_ID')
    assert_equal 'stateless', env_var('RUNNER')
    assert_equal sandbox_dir, env_var('SANDBOX')
  end

  def env_var(name)
    cmd = "printenv CYBER_DOJO_#{name}"
    assert_cyber_dojo_sh(cmd)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_avatar_users_exist
    etc_passwd = assert_cyber_dojo_sh 'cat /etc/passwd'
    all_avatars_names.each do |name|
      assert etc_passwd.include?(uid.to_s),
        "#{name}:#{uid}:#{etc_passwd}:#{image_name}"
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_group_exists
    assert_cyber_dojo_sh("getent group #{group}")
    entries = stdout.split(':')  # cyber-dojo:x:5000
    assert_equal group, entries[0], stdout
    assert_equal   gid, entries[2].to_i, stdout
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_avatar_has_home
    assert_equal home_dir, assert_cyber_dojo_sh('printenv HOME')
    assert_equal home_dir, assert_cyber_dojo_sh('cd ~ && pwd')
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_avatar_sandbox_properties
    assert_cyber_dojo_sh "[ -d #{sandbox_dir} ]" # sandbox exists
    refute_equal '', assert_cyber_dojo_sh("ls -A #{sandbox_dir}")
    assert_equal     uid.to_s, stat_sandbox_dir('u'), 'stat <uid>  sandbox_dir'
    assert_equal     gid.to_s, stat_sandbox_dir('g'), 'stat <gid>  sandbox_dir'
    assert_equal 'drwxr-xr-x', stat_sandbox_dir('A'), 'stat <perm> sandbox_dir'
  end

  def stat_sandbox_dir(ch)
    assert_cyber_dojo_sh("stat -c '%#{ch}' #{sandbox_dir}")
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_starting_files_properties
    run_cyber_dojo_sh({
      changed_files: { 'cyber-dojo.sh' => stat_cmd }
    })
    assert amber? # doing an stat
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
    assert_cyber_dojo_sh('ulimit -a')

    expected_max_data_size  =  4 * GB / KB
    expected_max_file_size  = 16 * MB / (block_size = 512)
    expected_max_stack_size =  8 * MB / KB

    assert_equal expected_max_data_size,  ulimit(:data_size)
    assert_equal expected_max_file_size,  ulimit(:file_size)
    assert_equal expected_max_stack_size, ulimit(:stack_size)
    assert_equal 0,                       ulimit(:core_size)
    assert_equal 128,                     ulimit(:file_locks)
    assert_equal 128,                     ulimit(:no_files)
    assert_equal 128,                     ulimit(:processes)
  end

  KB = 1024
  MB = 1024 * KB
  GB = 1024 * MB

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def ulimit(key)
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

  def assert_baseline_speed
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
    assert mean < max=800, "mean=#{mean}, max=#{max}"
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_files_can_be_created_in_sub_dirs_of_sandbox
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

  def assert_files_can_be_created_in_sub_sub_dirs_of_sandbox
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
    assert_equal 5, count
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

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  C_FORK_BOMB = <<~'CODE'
    #include <stdio.h>
    #include <unistd.h>
    int answer(void)
    {
        for(;;)
        {
            int pid = fork();
            fprintf(stdout, "fork() => %d\n", pid);
            fflush(stdout);
            if (pid == -1)
                break;
        }
        return 6 * 7;
    }
  CODE

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  SHELL_FORK_BOMB = <<~CODE
    bomb()
    {
      echo "bomb"
      bomb | bomb &
    }
    bomb
  CODE

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  FILE_HANDLE_BOMB = <<~'CODE'
    #include <stdio.h>
    int answer(void)
    {
      for (int i = 0;;i++)
      {
        char filename[42];
        sprintf(filename, "wibble%d.txt", i);
        FILE * f = fopen(filename, "w");
        if (f)
          fprintf(stdout, "fopen() != NULL %s\n", filename);
        else
        {
          fprintf(stdout, "fopen() == NULL %s\n", filename);
          break;
        }
      }
      return 6 * 7;
    }
  CODE

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_timed_out_or_printed(text)
    diagnostic = ":#{text}:#{quad}:"
    count = (stdout+stderr).lines.count { |line| line.include?(text) }
    assert (timed_out? || count > 0), diagnostic
  end

  def seen?(text)
    count = (stdout+stderr).lines.count { |line| line.include?(text) }
    count > 0
  end

end
