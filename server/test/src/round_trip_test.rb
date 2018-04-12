require_relative 'test_base'

class RoundTripTest < TestBase

  def self.hex_prefix
    'ECFA3'
  end

  # - - - - - - - - - - - - - - - - -

  test '527',
  %w( [Ubuntu] sent files are returned in json payload ready to round-trip ) do
    # Using [Ubuntu] because that's Perl-testsimple which does
    # not generated any text files. In contrast, Alpine is
    # CSharp-NUnit which does generate an .xml text file.
    in_kata_as('salmon') {
      run_cyber_dojo_sh
    }
    files = quad['files']
    refute_nil files
    assert_hash_equal(@previous_files, files)
  end

  # - - - - - - - - - - - - - - - - -

  test '528',
  %w( [C,assert] created binary files are not returned in json payload
  but created text files are ) do
    cyber_dojo_sh = [
      'make >/dev/null',
      'file --mime-encoding test',
      'echo "xxx" > newfile.txt',
    ].join(';')

    in_kata_as('salmon') {
      named_args = {
        changed_files: { 'cyber-dojo.sh' => cyber_dojo_sh }
      }
      run_cyber_dojo_sh(named_args)
    }

    assert stdout.include?('test: binary') # file --mime-encoding
    expected = starting_files
    expected['cyber-dojo.sh'] = cyber_dojo_sh
    expected['newfile.txt'] = "xxx\n"
    assert_hash_equal(expected, quad['files'])
  end

  # - - - - - - - - - - - - - - - - -

  test '529',
  %w( created text files in sub-dirs are returned in json payload ) do
    cyber_dojo_sh = 'mkdir sub && echo "xxx" > sub/newfile.txt'
    in_kata_as('salmon') {
      named_args = {
        changed_files: { 'cyber-dojo.sh' => cyber_dojo_sh }
      }
      run_cyber_dojo_sh(named_args)
    }
    expected = starting_files
    expected['cyber-dojo.sh'] = cyber_dojo_sh
    expected['sub/newfile.txt'] = "xxx\n"
    assert_hash_equal(expected, quad['files'])
  end

  # - - - - - - - - - - - - - - - - -

  def assert_hash_equal(expected, actual)
    assert_equal expected.keys.sort, actual.keys.sort
    expected.keys.each do |key|
      assert_equal expected[key], actual[key]
    end
  end

end
