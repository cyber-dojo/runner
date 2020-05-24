# frozen_string_literal: true
require_relative 'test_base'

class FeatureContainerPropertiesTest < TestBase

  def self.id58_prefix
    '3A8'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'D91', %w(
  requires bash, won't run in sh ) do
    run_cyber_dojo_sh(image_name:'alpine:latest') # has sh but not bash
    assert stdout.empty? || stdout.start_with?('cannot exec in a stopped state:'), ":#{stdout}:"
    assert stderr.empty? || stderr.start_with?('Error response from daemon:'), ":#{stderr}:"
    assert_equal 'faulty', colour
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'D98', %w( multiple container properties ) do
    cyber_dojo_sh = [
      "#{stat_cmd}                       > #{sandbox_dir}/files.stat", # [1]
      "cat /proc/1/cmdline | cut -c1-9   > #{sandbox_dir}/proc.1", # [2]
      "cat /etc/passwd                   > #{sandbox_dir}/passwd",
      "getent group #{group}             > #{sandbox_dir}/group",
      "printf ${HOME}                    > #{sandbox_dir}/home.dir",
      "env                               > #{sandbox_dir}/env.vars",
      "stat --printf='%u' #{sandbox_dir} > #{sandbox_dir}/dir.stat.u",
      "stat --printf='%g' #{sandbox_dir} > #{sandbox_dir}/dir.stat.g",
      "stat --printf='%A' #{sandbox_dir} > #{sandbox_dir}/dir.stat.A",
      "ulimit -a                         > #{sandbox_dir}/ulimit.all"
    ].join(' && ')

    assert_sss(cyber_dojo_sh)

    # [1] must be first so as not to see newly created files.
    # [2] On CircleCI, currently proc.1 is...  '/dev/init' + 0.chr + '--'
    # Yes, there is an embedded nul-character.
    # Depending on the version of docker you are using you may get
    # '/sbin/docker-init' instead of '/dev/init'
    # Either way, the embedded nul-character causes text_file_changes()
    # in runner.rb to see proc.1 as a binary file. Hence only the first
    # nine characters of proc/1/cmdline are saved, and proc.1 is seen
    # as a text file.
    proc1 = created_file('proc.1')
    expected_1 = '/dev/init'
    expected_2 = '/sbin/docker-init'[0...expected_1.size]
    assert [expected_1,expected_2].any?{|s|proc1.start_with?(s)}, proc1

    etc_passwd = created_file('passwd')
    etc_passwd_line = "sandbox:x:#{uid}:#{gid}:"
    assert etc_passwd.lines.detect{|line| line.start_with?(etc_passwd_line)}, etc_passwd

    fields = created_file('group').split(':')  # sandbox:x:51966
    assert_equal group, fields[0], :group_name
    assert_equal   gid, fields[2].to_i, :group_gid

    assert_equal home_dir, created_file('home.dir'), :home_dir

    env = created_file('env.vars')
    env_vars = Hash[env.split("\n").map{ |line| line.split('=') }]
    assert_equal  image_name, env_vars['CYBER_DOJO_IMAGE_NAME'], :cyber_dojo_image_name
    assert_equal          id, env_vars['CYBER_DOJO_ID'], :cyber_dojo_id
    assert_equal sandbox_dir, env_vars['CYBER_DOJO_SANDBOX'], :cyber_dojo_sandbox

    assert_equal uid.to_s,     created_file('dir.stat.u'), :uid
    assert_equal gid.to_s,     created_file('dir.stat.g'), :gid
    assert_equal 'drwxrwxrwt', created_file('dir.stat.A'), :permission

    expected_max_data_size  =  clang? ? 0 : 4 * GB / KB
    expected_max_file_size  = 16 * MB / (block_size = 1024)
    expected_max_stack_size =  8 * MB / KB
    assert_equal expected_max_data_size,  ulimit(:data_size),  :data_size
    assert_equal expected_max_file_size,  ulimit(:file_size),  :file_size
    assert_equal expected_max_stack_size, ulimit(:stack_size), :stack_size
    assert_equal 0,                       ulimit(:core_size),  :core_size
    assert_equal 128,                     ulimit(:file_locks), :file_locks
    assert_equal 256,                     ulimit(:open_files), :open_files
    assert_equal 128,                     ulimit(:processes),  :processes

    stats = files_stat
    assert_equal starting_files.keys.sort, stats.keys.sort
    starting_files.each do |filename, content|
      if filename === 'cyber-dojo.sh'
        content = cyber_dojo_sh
      end
      stat = stats[filename]
      refute_nil stat, filename
      diagnostic = { filename => stat }
      assert_equal '-rw-r--r--', stat[:permissions], diagnostic
      assert_equal          uid, stat[:uid        ], diagnostic
      assert_equal        group, stat[:group      ], diagnostic
      assert_equal content.size, stat[:size       ], diagnostic
    end
  end

  private

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

  ULIMIT_TABLE = {
    :core_size  => 'core file size',
    :data_size  => 'data seg size',
    :file_locks => 'file locks',
    :file_size  => 'file size',
    :open_files => 'open files',
    :processes  => 'max user processes',
    :stack_size => 'stack size'
  }

  def ulimit(key)
    ulimit = created_file('ulimit.all')
    text = ULIMIT_TABLE[key]
    diagnostic = "#{ulimit}\nno ulimit for #{key}"
    refute_nil text, diagnostic
    entry = ulimit.lines.find { |line| line.start_with?(text) }
    entry.split[-1].to_i
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def files_stat
    created_file('files.stat').lines.map.with_object({}) { |line,memo|
      attr = line.split
      filename = attr[0]
      memo[filename] = {
        permissions: attr[1],
                uid: attr[2].to_i,
              group: attr[3],
               size: attr[4].to_i
      }
    }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def created_file(filename)
    created[filename][:content]
  end

end
