# frozen_string_literal: true
require_relative 'test_base'

class FeatureContainerPropertiesTest < TestBase

  def self.id58_prefix
    '3A8'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'D91', %w(
  requires bash, won't run in sh ) do
    any_image_without_bash = 'alpine:latest'
    BashSheller.new(context).capture("docker pull #{any_image_without_bash}")
    context.puller.add(any_image_without_bash)
    run_cyber_dojo_sh(image_name:any_image_without_bash)
    assert stdout.empty?, pretty_result(:stdout)
    assert stderr.empty?, pretty_result(:stderr)
    assert_equal 'faulty', colour, pretty_result(:colour)
    pattern = /\[FATAL tini \(\d+\)\] exec bash failed: No such file or directory/
    assert log.match(pattern), pretty_result(:log)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test 'D98', %w( multiple container properties ) do
    context.puller.add(image_name)
    memory_dir = '/sys/fs/cgroup/memory'
    cyber_dojo_sh = [
      "#{stat_cmd}                       > #{sandbox_dir}/files.stat", # [1]
      "cat /proc/1/cmdline | cut -c1-9   > #{sandbox_dir}/proc.1", # [2]
      "cat /etc/passwd                   > #{sandbox_dir}/passwd",
      "getent group #{group}             > #{sandbox_dir}/group",
      "printf ${HOME}                    > #{sandbox_dir}/home.dir",
      "env | grep CYBER_DOJO_IMAGE_NAME  > #{sandbox_dir}/env.var.image_name",
      "env | grep CYBER_DOJO_ID          > #{sandbox_dir}/env.var.id",
      "env | grep CYBER_DOJO_SANDBOX     > #{sandbox_dir}/env.var.sandbox",
      "stat --printf='%u' #{sandbox_dir} > #{sandbox_dir}/dir.stat.u",
      "stat --printf='%g' #{sandbox_dir} > #{sandbox_dir}/dir.stat.g",
      "stat --printf='%A' #{sandbox_dir} > #{sandbox_dir}/dir.stat.A",
      "ulimit -c                         > #{sandbox_dir}/ulimit.core_size",
      "ulimit -d                         > #{sandbox_dir}/ulimit.data_size",
      "ulimit -f                         > #{sandbox_dir}/ulimit.file_size",
      "ulimit -n                         > #{sandbox_dir}/ulimit.file_count",
      "ulimit -x                         > #{sandbox_dir}/ulimit.file_locks",
      "ulimit -u                         > #{sandbox_dir}/ulimit.process_count",
      "ulimit -s                         > #{sandbox_dir}/ulimit.stack_size",
      "cat #{memory_dir}/memory.limit_in_bytes      > #{sandbox_dir}/memory.limit_in_bytes",
      "cat #{memory_dir}/memory.kmem.limit_in_bytes > #{sandbox_dir}/memory.kmem.limit_in_bytes"
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

    assert_equal  image_name, env_var('image_name'), :cyber_dojo_image_name
    assert_equal          id, env_var('id'), :cyber_dojo_id
    assert_equal sandbox_dir, env_var('sandbox'), :cyber_dojo_sandbox

    assert_equal uid.to_s,     created_file('dir.stat.u'), :uid
    assert_equal gid.to_s,     created_file('dir.stat.g'), :gid
    assert_equal 'drwxrwxrwt', created_file('dir.stat.A'), :permission

    expected_max_data_size  =  clang? ? 0 : 4*GB / BLOCK_SIZE
    expected_max_file_size  = 16*MB / BLOCK_SIZE
    expected_max_stack_size = 16*MB / BLOCK_SIZE

    assert_ulimit 0,                       :core_size
    assert_ulimit expected_max_data_size,  :data_size
    assert_ulimit expected_max_file_size,  :file_size
    assert_ulimit 1024,                    :file_locks
    assert_ulimit 1024,                    :file_count
    assert_ulimit expected_max_stack_size, :stack_size
    assert_ulimit 1024,                    :process_count

    assert_equal 768*MB, created_file('memory.limit_in_bytes').to_i, :memory_limit
    assert_equal 768*MB, created_file('memory.kmem.limit_in_bytes').to_i, :kmem_memory_limit

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
  BLOCK_SIZE = 1024

  def clang?
    image_name.start_with?('cyberdojofoundation/clang')
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_ulimit(expected, key)
    actual = created_file("ulimit.#{key}").to_i
    assert_equal expected, actual, key
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

  def env_var(name)
    created_file("env.var.#{name}").split('=')[1].strip
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def created_file(filename)
    created[filename][:content]
  end

end
