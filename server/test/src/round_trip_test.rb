require_relative 'bash_stub_tar_pipe_out'
require_relative 'test_base'

class RoundTripTest < TestBase

  def self.hex_prefix
    'ECFA3'
  end

  # - - - - - - - - - - - - - - - - -

  test '528', %w(
  created text files (including dot files) are returned
  but created binary files are not ) do
    script = [
      'dd if=/dev/zero of=binary.dat bs=1c count=1',
      'file --mime-encoding binary.dat',
      'echo "xxx" > newfile.txt',
      'echo "yyy" > .dotfile'
    ].join(';')

    all_OSes.each do |os|
      @os = os
      in_kata_as('salmon') { assert_cyber_dojo_sh(script) }

      assert stdout.include?('binary.dat: binary') # file --mime-encoding

      assert_hash_equal({
        'newfile.txt' => 'xxx' + "\n",
        '.dotfile' => 'yyy' + "\n"
      }, new_files)
      assert_hash_equal({}, deleted_files)
      assert_hash_equal(@previous_files, unchanged_files)
      assert_hash_equal({}, changed_files)
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
      in_kata_as('salmon') { assert_cyber_dojo_sh(script) }

      assert_hash_equal({
        'sub/newfile.txt' => "xxx\n"
      }, new_files)
      assert_hash_equal({}, deleted_files)
      assert_hash_equal(@previous_files, unchanged_files)
      assert_hash_equal({}, changed_files)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '530', %w( deleted files are detected ) do
    all_OSes.each do |os|
      @os = os
      in_kata_as('salmon') {
        script = "rm #{src_file(os)}"
        assert_cyber_dojo_sh(script)

        assert_hash_equal({}, new_files)
        assert_equal [src_file(os)], deleted_files.keys
        @previous_files.delete(src_file(os))
        assert_hash_equal(@previous_files, unchanged_files)
        assert_hash_equal({}, changed_files)
      }
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '531', %w( changed files are detected ) do
    all_OSes.each do |os|
      @os = os
      in_kata_as('salmon') {
        script = "echo 'XXX' >> #{src_file(os)}"
        assert_cyber_dojo_sh(script)

        assert_hash_equal({}, new_files)
        assert_hash_equal({}, deleted_files)
        @previous_files.delete(src_file(os))
        assert_hash_equal(@previous_files, unchanged_files)
        assert_equal [src_file(os)], changed_files.keys
      }
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '62A',
  %w( files bigger than 10K are truncated ) do
    script = 'yes "123456789" | head -n 1042 > large_file.txt'
    all_OSes.each do |os|
      @os = os
      in_kata_as('salmon') { assert_cyber_dojo_sh(script) }
      expected = "123456789\n" * 1024
      expected += "\n"
      expected += 'output truncated by cyber-dojo'

      assert_hash_equal({
        'large_file.txt' => expected
      }, new_files)
      assert_hash_equal({}, deleted_files)
      assert_hash_equal(@previous_files, unchanged_files)
      assert_hash_equal({}, changed_files)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '62B',
  %w( a crippled container, eg from a fork-bomb, returns everything unchanged ) do
    all_OSes.each do |os|
      @os = os
      stub = BashStubTarPipeOut.new('fail')
      @external = External.new({ 'bash' => stub })
      in_kata_as('salmon') {
        with_captured_log {
          run_cyber_dojo_sh
        }
      }
      assert stub.fired?
      assert_hash_equal({}, new_files)
      assert_hash_equal({}, deleted_files)
      assert_hash_equal(@previous_files, unchanged_files)
      assert_hash_equal({}, changed_files)
    end
  end

  private # = = = = = = = = = = = = =

  def all_OSes
    [ :Alpine, :Ubuntu, :Debian ]
  end

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
      assert_equal expected[key], actual[key]
    end
  end

end
