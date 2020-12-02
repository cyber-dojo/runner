# frozen_string_literal: true
require_relative '../test_base'

module Client
  class CreatedFilesTest < TestBase

    def self.id58_prefix
      '2D1'
    end

    # - - - - - - - - - - - - - - - - -

    test '160',
    %w( round-tripping: example of no file changes ) do
      set_context
      run_cyber_dojo_sh
      assert_equal({}, created, :created)
      assert_equal([], deleted, :deleted)
      assert_equal({}, changed, :changed)
    end

    # - - - - - - - - - - - - - - - - -

    c_assert_test '161',
    %w( created binary files are not returned
    but created text files are ) do
      set_context
      assert_cyber_dojo_sh([
        'make',
        'file --mime-encoding test',
        'echo -n "xxx" > newfile.txt',
      ].join("\n"))
      assert stdout.include?('test: binary'), stdout # file --mime-encoding
      assert_equal({ 'newfile.txt' => intact('xxx') }, created, :created)
      assert_equal([], deleted, :deleted)
      assert_equal({}, changed, :changed)
    end

    # - - - - - - - - - - - - - - - - -

    test '523',
    %w(
    created text file called stdout
    is kept separate to actual stdout ) do
      set_context
      assert_cyber_dojo_sh([
        'make',
        'file --mime-encoding test',
        'echo -n "Hello" > stdout',
      ].join("\n"))
      assert stdout.include?('test: binary'), stdout # file --mime-encoding
      assert_equal({ 'stdout' => intact('Hello') }, created, :created)
      assert_equal([], deleted, :deleted)
      assert_equal({}, changed, :changed)
    end

    # - - - - - - - - - - - - - - - - -

    test '524', %w(
    created text files are returned when
    their names have leading hyphens which must not
    be read as a tar option
    ) do
      set_context
      leading_hyphen = '-JPlOLNY7yt_fFndapHwIg'
      script = "printf 'xxx' > '#{leading_hyphen}';"
      assert_cyber_dojo_sh(script)
      assert_equal({ leading_hyphen => intact('xxx') }, created, :created)
      assert_equal([], deleted, :deleted)
      assert_equal({}, changed, :changed)
    end

    # - - - - - - - - - - - - - - - - -

    test '526', %w(
    created text files, including dot files, are returned
    ) do
      set_context
      assert_cyber_dojo_sh([
        'printf "xxx" > newfile.txt',
        'printf "yyy" > .dotfile'
      ].join(';'))
      assert_equal({
        'newfile.txt' => intact('xxx'),
        '.dotfile' => intact('yyy')
      }, created, :created)
      assert_equal([], deleted, :deleted)
      assert_equal({}, changed, :changed)
    end

    # - - - - - - - - - - - - - - - - -

    c_assert_test '530', %w(
    deleted text filenames are returned
    ) do
      set_context
      filename = 'hiker.c'
      script = "rm #{filename}"
      assert_cyber_dojo_sh(script)
      assert_equal({}, created, :created)
      assert_equal([filename], deleted, :deleted)
      assert_equal({}, changed, :changed)
    end

    # - - - - - - - - - - - - - - - - -

    test '533', %w(
    single-char new text files are returned
    ) do
      set_context
      # The file utility says single-char files are binary files!
      filename = 'one-char.txt'
      ch = 'x'
      script = "printf '#{ch}' > #{filename}"
      assert_cyber_dojo_sh(script)
      assert_equal({filename => intact(ch)}, created, :created)
      assert_equal([], deleted, :deleted)
      assert_equal({}, changed, :changed)
    end

    # - - - - - - - - - - - - - - - - -

    test '62C', %w(
    no text files under /sandbox at all, returns everything deleted
    ) do
      set_context
      assert_cyber_dojo_sh('rm -rf /sandbox/* /sandbox/.*')
      assert_equal({}, created, :created)
      assert_equal(manifest['visible_files'].keys.sort, deleted, :deleted)
      assert_equal({}, changed, :changed)
    end

    # - - - - - - - - - - - - - - - - -

    test '12A',
    %w( created text files in /sandbox sub-dirs are returned ) do
      set_context
      # The tar-pipe handles creating dir structure
      assert_browser_can_create_files_in_sandbox_sub_dir('s1')
      assert_browser_can_create_files_in_sandbox_sub_dir('s1/s2')
    end

    # - - - - - - - - - - - - - - - - - - - - - - - - - -

    test '12B',
    %w( created text files in /sandbox sub-dirs are returned ) do
      set_context
      assert_cyber_dojo_sh_can_create_files_in_sandbox_sub_dir('d1')
      assert_cyber_dojo_sh_can_create_files_in_sandbox_sub_dir('d1/d2/d3')
    end

    # - - - - - - - - - - - - - - - - - - - - - - - - - -

    test '12C',
    %w( deleted text filenames from /sandbox sub-dir are returned ) do
      set_context
      assert_cyber_dojo_sh_can_delete_files_from_sandbox_sub_dir('c1')
      assert_cyber_dojo_sh_can_delete_files_from_sandbox_sub_dir('c1/c2/c3')
    end

    private

    def assert_browser_can_create_files_in_sandbox_sub_dir(sub_dir)
      filename = 'hello.txt'
      content = 'the boy stood on the burning deck'
      run_cyber_dojo_sh(
        changed: { 'cyber-dojo.sh' => "cd #{sub_dir} && #{stat_cmd}" },
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
      assert_cyber_dojo_sh([
        "mkdir -p #{sub_dir}",
        "printf #{content} > #{sub_dir}/#{filename}",
        "cd #{sub_dir}",
        stat_cmd
      ].join(' && '))
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

  end
end
