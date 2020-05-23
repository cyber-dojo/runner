# frozen_string_literal: true
require_relative 'test_base'

class FeatureSandboxTextFilesChangesTest < TestBase

  def self.id58_prefix
    'ECF'
  end

  # - - - - - - - - - - - - - - - - -

  test '524', %w(
  created text files are returned when
  their names have leading hyphens which must not
  be read as a tar option
  ) do
    leading_hyphen = '-JPlOLNY7yt_fFndapHwIg'
    script = "printf 'xxx' > '#{leading_hyphen}';"
    assert_sss(script)
    assert_created({leading_hyphen => intact('xxx')})
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  test '526', %w(
  created text files, including dot files, are returned
  ) do
    assert_sss([
      'printf "xxx" > newfile.txt',
      'printf "yyy" > .dotfile'
    ].join(';'))
    assert_created({
      'newfile.txt' => intact('xxx'),
      '.dotfile' => intact('yyy')
    })
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  test '527', %w(
  created binary files are not returned
  ) do
    script = [
      'dd if=/dev/zero of=binary.dat bs=1c count=42',
      'file --mime-encoding binary.dat'
    ].join(';')
    assert_sss(script)
    assert stdout.include?('binary.dat: binary')
    assert_created({})
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  test '530', %w(
  deleted text filenames are returned
  ) do
    filename = any_src_file
    script = "rm #{filename}"
    assert_sss(script)
    assert_created({})
    assert_deleted([filename])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  test '531', %w(
  changed text files are returned
  ) do
    filename = any_src_file
    content = 'XXX'
    script = "printf '#{content}' > #{filename}"
    assert_sss(script)
    assert_created({})
    assert_deleted([])
    assert_changed({filename => intact(content)})
  end

  # - - - - - - - - - - - - - - - - -

  test '532', %w(
  empty new text files are returned
  ) do
    # The file utility says empty files are binary files!
    filename = 'empty.txt'
    script = "touch #{filename}"
    assert_sss(script)
    assert_created({filename => intact('')})
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  test '533', %w(
  single-char new text files are returned
  ) do
    # The file utility says single-char files are binary files!
    filename = 'one-char.txt'
    ch = 'x'
    script = "printf '#{ch}' > #{filename}"
    assert_sss(script)
    assert_created({filename => intact(ch)})
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  test '62C', %w(
  no text files under /sandbox at all, returns everything deleted
  ) do
    assert_sss('rm -rf /sandbox/* /sandbox/.*')
    assert_created({})
    assert_deleted(manifest['visible_files'].keys.sort)
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  test '12A',
  %w( create text files in /sandbox sub-dirs are returned ) do
    # The tar-pipe handles creating dir structure
    assert_browser_can_create_files_in_sandbox_sub_dir('s1')
    assert_browser_can_create_files_in_sandbox_sub_dir('s1/s2')
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '12B',
  %w( created text files in /sandbox sub-dirs are returned ) do
    assert_cyber_dojo_sh_can_create_files_in_sandbox_sub_dir('d1')
    assert_cyber_dojo_sh_can_create_files_in_sandbox_sub_dir('d1/d2/d3')
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '12C',
  %w( deleted text filenames from /sandbox sub-dir are returned ) do
    assert_cyber_dojo_sh_can_delete_files_from_sandbox_sub_dir('c1')
    assert_cyber_dojo_sh_can_delete_files_from_sandbox_sub_dir('c1/c2/c3')
  end

  private

  def assert_browser_can_create_files_in_sandbox_sub_dir(sub_dir)
    filename = 'hello.txt'
    content = 'the boy stood on the burning deck'
    assert_cyber_dojo_sh(
      "cd #{sub_dir} && #{stat_cmd}",
      created: { "#{sub_dir}/#{filename}" => content }
    )
    assert_stats(filename, '-rw-r--r--', content.length)
    # Text file changes occur after cyber-dojo.sh runs.
    # Browser-created text files are untarred into /sandbox
    # *before* cyber-dojo.sh runs and so are not changes.
    assert_equal({}, created, :created)
    assert_equal({}, changed, :changed)
    assert_equal([], deleted, :deleted)
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def assert_cyber_dojo_sh_can_create_files_in_sandbox_sub_dir(sub_dir)
    filename = 'bonjour.txt'
    content = 'xyzzy'
    assert_sss([
      "mkdir -p #{sub_dir}",
      "printf #{content} > #{sub_dir}/#{filename}",
      "cd #{sub_dir}",
      stat_cmd
    ].join(' && '))
    assert_stats(filename, '-rw-r--r--', content.length)
    expected = {
      "#{sub_dir}/#{filename}" => {
        content: content,
        truncated: false
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
    run_cyber_dojo_sh(
      created: { filename => content },
      changed: { 'cyber-dojo.sh' => cmd }
    )
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
    stdout.lines.map.with_object({}) do |line,memo|
      attr = line.split
      filename = attr[0]           # eg hiker.h
      memo[filename] = {
        permissions: attr[1],      # eg -rwxr--r--
                uid: attr[2].to_i, # eg 40045
              group: attr[3],      # eg cyber-dojo
               size: attr[4].to_i, # eg 136
      }
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  def any_src_file
    manifest['visible_files'].keys.find do |filename|
      filename.split('.')[0].upcase === 'HIKER'
    end
  end

end
