# frozen_string_literal: true
require_relative 'test_base'

class ContainerPropertiesTest < TestBase

  def self.hex_prefix
    '3A8'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'D91', %w(
  requires bash, won't run in sh ) do
    assert_equal '/bin/bash', assert_cyber_dojo_sh('printf ${SHELL}')
    image_name = 'alpine:latest'
    with_captured_log {
      run_cyber_dojo_sh({image_name:image_name})
    }
    expected_info = "no /usr/local/bin/red_amber_green.rb in #{image_name}"
    refute_nil stdout+stderr
    assert_equal 'faulty', colour
    assert_equal image_name, diagnostic['image_name'], :image_name
    assert_equal id, diagnostic['id'], :id
    assert_equal expected_info, diagnostic['info'], :info
    assert_nil diagnostic['message'], :message
    assert_nil diagnostic['rag_lambda'], :rag_lambda
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'D92', %w( requires a /sandbox/ dir ) do
    image_name = 'cyberdojo/runner'
    with_captured_log {
      run_cyber_dojo_sh({image_name:image_name})
    }
    expected_info = "no /usr/local/bin/red_amber_green.rb in #{image_name}"
    refute_nil stdout+stderr
    assert_equal 'faulty', colour
    assert_equal image_name, diagnostic['image_name'], :image_name
    assert_equal id, diagnostic['id'], :id
    assert_equal expected_info, diagnostic['info'], :info
    assert_nil diagnostic['message'], :message
    assert_nil diagnostic['rag_lambda'], :rag_lambda
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'D93', %w( pid1 is running init process ) do
    cmd = 'cat /proc/1/cmdline'
    proc1 = assert_cyber_dojo_sh(cmd)
    # odd, but there _is_ an embedded nul-character
    expected_1 = '/dev/init' + 0.chr + '--'
    # The result of a docker-compose.yml's
    #     init: true
    # varies depending on what version of docker you are using
    expected_2 = '/sbin/docker-init'
    assert proc1.start_with?(expected_1) || proc1.start_with?(expected_2), proc1
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'D94', %w( sandbox user exists ) do
    etc_passwd = assert_cyber_dojo_sh('cat /etc/passwd')
    name = 'sandbox'
    diagnostic = "#{name}:#{uid}:#{etc_passwd}:#{image_name}"
    assert etc_passwd.include?(uid.to_s), diagnostic
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'D95', %w( sandbox group exists ) do
    assert_cyber_dojo_sh("getent group #{group}")
    entries = stdout.split(':')  # sandbox:x:51966
    assert_equal group, entries[0], stdout
    assert_equal   gid, entries[2].to_i, stdout
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'D96', %w( sandbox user has home ) do
    assert_equal home_dir, assert_cyber_dojo_sh('printf ${HOME}')
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'D97', %w( env-vars are set ) do
    assert_equal  image_name, env_var('IMAGE_NAME')
    assert_equal          id, env_var('ID')
    assert_equal sandbox_dir, env_var('SANDBOX')
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'D98', %w( sandbox/ dir properties ) do
    assert_cyber_dojo_sh "[ -d #{sandbox_dir} ]" # sandbox exists
    refute_equal '', assert_cyber_dojo_sh("ls -A #{sandbox_dir}")
    assert_equal     uid.to_s, stat_sandbox_dir('u'), 'stat <uid>  sandbox_dir'
    assert_equal     gid.to_s, stat_sandbox_dir('g'), 'stat <gid>  sandbox_dir'
    assert_equal 'drwxrwxrwt', stat_sandbox_dir('A'), 'stat <perm> sandbox_dir'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'D99', %w( starting-files properties ) do
    run_cyber_dojo_sh({
      changed: { 'cyber-dojo.sh' => stat_cmd }
    })
    assert_equal '', stderr
    assert_equal starting_files.keys.sort, stdout_stats.keys.sort
    starting_files.each do |filename, content|
      if filename === 'cyber-dojo.sh'
        content = stat_cmd
      end
      assert_stats(filename, '-rw-r--r--', content.length)
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'D9A', %w( ulimits are set ) do
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

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'D9B', %w( time-stamp microsecond gramularity ) do
    # On _default_ Alpine date-time file-stamps are to
    # the second granularity. In other words, the
    # microseconds value is always '000000000'.
    # Make sure the tar-piped files have fixed this.
    run_cyber_dojo_sh({
      changed: { 'cyber-dojo.sh' => stat_cmd }
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

  private # = = = = = = = = = = = = = = = = = = = = = =

  def env_var(name)
    cmd = "printf ${CYBER_DOJO_#{name}}"
    assert_cyber_dojo_sh(cmd)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def stat_sandbox_dir(ch)
    assert_cyber_dojo_sh("stat --printf='%#{ch}' #{sandbox_dir}")
  end

  def home_dir
    '/home/sandbox'
  end

  def sandbox_dir
    '/sandbox'
  end

  def gid
    51966
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

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
    if os === :Alpine
      txt = row[0]
    end
    if os === :Ubuntu
      txt = row[1]
    end
    entry = stdout.lines.detect { |line| line.start_with?(txt) }
    entry.split[-1].to_i
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
    stdout.lines.collect { |line|
      attr = line.split
      [attr[0], { # filename
        permissions: attr[1],
                uid: attr[2].to_i,
              group: attr[3],
               size: attr[4].to_i,
               time: attr[6],
      }]
    }.to_h
  end

end
