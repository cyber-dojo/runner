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

  multi_os_test 'D98', %w( various container properties ) do
    assert_cyber_dojo_sh([
      "cat /proc/1/cmdline | cut -c1-9   > #{sandbox_dir}/proc.1", # [1]
      "cat /etc/passwd                   > #{sandbox_dir}/passwd",
      "getent group #{group}             > #{sandbox_dir}/group",
      "printf ${HOME}                    > #{sandbox_dir}/home.dir",
      "env                               > #{sandbox_dir}/env.vars",
      "stat --printf='%u' #{sandbox_dir} > #{sandbox_dir}/stat.u",
      "stat --printf='%g' #{sandbox_dir} > #{sandbox_dir}/stat.g",
      "stat --printf='%A' #{sandbox_dir} > #{sandbox_dir}/stat.A"
    ].join(' && '))

    # [1] On inspection, proc.1 is...  '/dev/init' + 0.chr + '--'
    # Yes, there is an embedded nul-character.
    # Depending on the version of docker you are using you may get
    # '/sbin/docker-init' instead of '/dev/init'
    # Either way, the embedded nul-character causes text_file_changes()
    # in runner.rb to see proc.1 as a binary file. Hence only the first
    # nine characters of proc/1/cmdline are saved, and proc.1 is
    # seen as a text file.
    proc1 = created['proc.1']['content']
    # odd, but there _is_ an embedded nul-character
    expected_1 = ('/dev/init' + 0.chr + '--')[0...9]
    expected_2 = ('/sbin/docker-init')[0...9]
    assert proc1.start_with?(expected_1) || proc1.start_with?(expected_2), proc1

    etc_passwd = created['passwd']['content']
    assert etc_passwd.include?(uid.to_s), etc_passwd

    fields = created['group']['content'].split(':')  # sandbox:x:51966
    assert_equal group, fields[0], :group_name
    assert_equal   gid, fields[2].to_i, :group_gid

    assert_equal home_dir, created['home.dir']['content'], :home_dir

    env = created['env.vars']['content']
    env_vars = Hash[env.split("\n").map{ |line| line.split('=') }]
    assert_equal  image_name, env_vars['CYBER_DOJO_IMAGE_NAME'], :cyber_dojo_image_name
    assert_equal          id, env_vars['CYBER_DOJO_ID'], :cyber_dojo_id
    assert_equal sandbox_dir, env_vars['CYBER_DOJO_SANDBOX'], :cyber_dojo_sandbox

    assert_equal uid.to_s,     created['stat.u']['content'], :uid
    assert_equal gid.to_s,     created['stat.g']['content'], :gid
    assert_equal 'drwxrwxrwt', created['stat.A']['content'], :permission
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
