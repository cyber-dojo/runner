# frozen_string_literal: true
require_relative 'test_base'

class SandboxSubDirTest < TestBase

  def self.id58_prefix
    'D8D'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '12A',
  'browser can create files in sandbox/ sub-dirs' do
    # The tar-pipe handles creating dir structure
    assert_browser_can_create_files_in_sandbox_sub_dir('s1')
    assert_browser_can_create_files_in_sandbox_sub_dir('s1/s2')
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '12B',
  'cyber-dojo.sh can create files in sandbox/ sub-dirs' do
    assert_cyber_dojo_sh_can_create_files_in_sandbox_sub_dir('d1')
    assert_cyber_dojo_sh_can_create_files_in_sandbox_sub_dir('d1/d2/d3')
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  multi_os_test '12C',
  %w( cyber-dojo.sh can delete files from sandbox/ sub-dir ) do
    assert_cyber_dojo_sh_can_delete_files_from_sandbox_sub_dir('c1')
    assert_cyber_dojo_sh_can_delete_files_from_sandbox_sub_dir('c1/c2/c3')
  end

  private # = = = = = = = = = = = = = = = = = = = = = =

  def assert_browser_can_create_files_in_sandbox_sub_dir(sub_dir)
    filename = 'hello.txt'
    content = 'the boy stood on the burning deck'
    run_cyber_dojo_sh({
      created: { "#{sub_dir}/#{filename}" => content },
      changed: { 'cyber-dojo.sh' => "cd #{sub_dir} && #{stat_cmd}" }
    })
    assert_stats(filename, '-rw-r--r--', content.length)
    assert_equal({}, created, :created)
    assert_equal({}, changed, :changed)
    assert_equal([], deleted, :deleted)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh_can_create_files_in_sandbox_sub_dir(sub_dir)
    filename = 'bonjour.txt'
    content = 'xyzzy'
    cmd = [
      "mkdir -p #{sub_dir}",
      "printf #{content} > #{sub_dir}/#{filename}",
      "cd #{sub_dir}",
      stat_cmd
    ].join(' && ')
    run_cyber_dojo_sh({
      changed: { 'cyber-dojo.sh' => cmd }
    })
    assert_stats(filename, '-rw-r--r--', content.length)
    expected = {
      "#{sub_dir}/#{filename}" => {
        'content' => content,
        'truncated' => false
      }
    }
    assert_equal(expected, created, :created)
    assert_equal({}, changed, :changed)
    assert_equal([], deleted, :deleted)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh_can_delete_files_from_sandbox_sub_dir(sub_dir)
    filename = "#{sub_dir}/goodbye.txt"
    content = 'goodbye, world'
    cmd = [
      "rm #{filename}",
      "cd #{sub_dir}",
      stat_cmd
    ].join(' && ')
    run_cyber_dojo_sh({
      created: { filename => content },
      changed: { 'cyber-dojo.sh' => cmd }
    })
    assert_equal([], stdout_stats.keys, :keys)
    assert_equal({}, created, :created)
    assert_equal({}, changed, :changed)
    assert_equal([filename], deleted, :deleted)
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
    stdout.lines.collect { |line|
      attr = line.split
      [attr[0], {         # filename eg hiker.h
        permissions: attr[1],      # eg -rwxr--r--
                uid: attr[2].to_i, # eg 40045
              group: attr[3],      # eg cyber-dojo
               size: attr[4].to_i, # eg 136
         time_stamp: attr[6],      # eg 07:03:14.539952547
      }]
    }.to_h
  end

end
