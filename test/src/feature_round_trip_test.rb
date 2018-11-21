require_relative 'bash_stub_tar_pipe_out'
require_relative 'test_base'

class RoundTripTest < TestBase

  def self.hex_prefix
    'ECF'
  end

  # - - - - - - - - - - - - - - - - -

  test '528', %w(
  created text files (including dot files) are returned
  but created binary files are not ) do
    script = [
      'dd if=/dev/zero of=binary.dat bs=1c count=42',
      'file --mime-encoding binary.dat',
      'echo "xxx" > newfile.txt',
      'echo "yyy" > .dotfile'
    ].join(';')

    all_OSes.each do |os|
      @os = os
      assert_cyber_dojo_sh(script)

      assert stdout.include?('binary.dat: binary') # file --mime-encoding

      assert_hash_equal({
        'newfile.txt' => file('xxx' + "\n"),
        '.dotfile' => file('yyy' + "\n")
      }, created_files)
      assert_equal({}, deleted_files)
      assert_equal({}, changed_files)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '529',
  %w( text files created in sub-dirs are returned in json payload ) do
    script = [
      'mkdir sub',
      'echo "xxx" > sub/newfile.txt'
    ].join(';')

    all_OSes.each do |os|
      @os = os
      assert_cyber_dojo_sh(script)

      assert_equal({ 'sub/newfile.txt' => file("xxx\n") }, created_files)
      assert_equal({}, deleted_files)
      assert_equal({}, changed_files)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '530', %w( deleted files are detected ) do
    all_OSes.each do |os|
      @os = os
      script = "rm #{src_file(os)}"
      assert_cyber_dojo_sh(script)

      assert_equal({}, created_files)
      assert_equal [src_file(os)], deleted_files.keys # FAILS
      assert_equal({}, changed_files)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '531', %w( changed files are detected ) do
    all_OSes.each do |os|
      @os = os
      script = "echo 'XXX' >> #{src_file(os)}"
      assert_cyber_dojo_sh(script)

      assert_equal({}, created_files)
      assert_equal({}, deleted_files)
      assert_equal [src_file(os)], changed_files.keys
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '532', %w( empty new text files are detected ) do
    # runner runs create_text_file_tar_list.sh which
    # uses the file utility to detect non binary files.
    # However it says empty files are binary files.
    all_OSes.each do |os|
      @os = os
      script = 'touch empty.file'
      assert_cyber_dojo_sh(script)

      assert_equal({'empty.file' => file('')}, created_files)
      assert_equal({}, deleted_files)
      assert_equal({}, changed_files)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '533', %w( single-char new text files are detected ) do
    # runner runs create_text_file_tar_list.sh which
    # uses the file utility to detect non binary files.
    # However file says single-char files are binary files!
    all_OSes.each do |os|
      @os = os
      script = 'echo -n x > small.file'
      assert_cyber_dojo_sh(script)

      assert_equal({'small.file' => file('x')}, created_files)
      assert_equal({}, deleted_files)
      assert_equal({}, changed_files)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '62B',
  %w( a crippled container, eg from a fork-bomb, returns everything unchanged ) do
    all_OSes.each do |os|
      @os = os
      stub = BashStubTarPipeOut.new('fail')
      @external = External.new({ 'bash' => stub })
      with_captured_log {
        run_cyber_dojo_sh
      }
      assert stub.fired?
      assert_equal({}, created_files)
      assert_equal({}, deleted_files)
      assert_equal({}, changed_files)
    end
  end

  private # = = = = = = = = = = = = =

  def src_file(os)
    case os
    when :Alpine then 'Hiker.cs'
    when :Ubuntu then 'hiker.pl'
    when :Debian then 'hiker.py'
    end
  end

  # - - - - - - - - - - - - - - - - -

  def assert_hash_equal(expected, actual)
    assert_equal expected.keys.sort, actual.keys.sort
    expected.keys.each do |key|
      assert_equal expected[key], actual[key], key
    end
  end

end
