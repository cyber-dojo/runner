require_relative 'bash_stub_tar_pipe_out'
require_relative 'test_base'

class RoundTripTest < TestBase

  def self.hex_prefix
    'ECF'
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '524', %w(
  filenames with leading hyphens can interfere with text-file tar-pipe
  unless filenames are read from stdin verbatim
  ) do
    interfere = '-JPlOLNY7yt_fFndapHwIg'
    script = "printf 'xxx' > '#{interfere}';"
    assert_cyber_dojo_sh(script)
    assert_created({interfere => intact('xxx')})
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '526', %w(
  created text files (including dot files) are returned
  ) do
    script = [
      'printf "xxx" > newfile.txt',
      'printf "yyy" > .dotfile'
    ].join(';')
    assert_cyber_dojo_sh(script)
    assert_created({
      'newfile.txt' => intact('xxx'),
      '.dotfile' => intact('yyy')
    })
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '527', %w(
  created binary files are not returned
  ) do
    script = [
      'dd if=/dev/zero of=binary.dat bs=1c count=42',
      'file --mime-encoding binary.dat'
    ].join(';')
    assert_cyber_dojo_sh(script)
    assert stdout.include?('binary.dat: binary')
    assert_created({})
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '529', %w(
  text files created in sub-dirs are returned
  ) do
    dirname = 'sub'
    path = "#{dirname}/newfile.txt"
    content = 'jjj'
    script = [
      "mkdir #{dirname}",
      "printf '#{content}' > #{path}"
    ].join(';')
    assert_cyber_dojo_sh(script)
    assert_created({ path => intact(content) })
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '530', %w(
  deleted files are detected
  ) do
    filename = any_src_file
    script = "rm #{filename}"
    assert_cyber_dojo_sh(script)
    assert_created({})
    assert_deleted([filename])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '531', %w(
  changed files are detected
  ) do
    filename = any_src_file
    content = 'XXX'
    script = "printf '#{content}' > #{filename}"
    assert_cyber_dojo_sh(script)
    assert_created({})
    assert_deleted([])
    assert_changed({filename => intact(content)})
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '532', %w(
  empty new text files are detected
  ) do
    # The file utility says empty files are binary files!
    filename = 'empty.txt'
    script = "touch #{filename}"
    assert_cyber_dojo_sh(script)
    assert_created({filename => intact('')})
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '533', %w(
  single-char new text files are detected
  ) do
    # The file utility says single-char files are binary files!
    filename = 'one-char.txt'
    ch = 'x'
    script = "printf '#{ch}' > #{filename}"
    assert_cyber_dojo_sh(script)
    assert_created({filename => intact(ch)})
    assert_deleted([])
    assert_changed({})
  end

  # - - - - - - - - - - - - - - - - -

  multi_os_test '62C', %w(
  no text files under /sandbox at all, returns everything deleted
  ) do
    assert_cyber_dojo_sh('rm -rf /sandbox/* /sandbox/.*')
    assert_created({})
    assert_deleted(manifest['visible_files'].keys.sort)
    assert_changed({})
  end

  private # = = = = = = = = = = = = =

  def any_src_file
    manifest['visible_files'].keys.find do |filename|
      filename.split('.')[0].upcase === 'HIKER'
    end
  end

end
