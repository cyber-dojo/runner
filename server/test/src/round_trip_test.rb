require_relative 'test_base'

class RoundTripTest < TestBase

  def self.hex_prefix
    'ECFA3'
  end

  # - - - - - - - - - - - - - - - - -

  test '527',
  %w( sent files are returned in json payload ready to round-trip ) do
    in_kata_as('salmon') {
      run_cyber_dojo_sh
      assert_colour 'red'
    }
    files = quad['files']
    refute_nil files
    files.delete('TestResult.xml')
    assert_hash_equal(@previous_files, files)
  end

  # - - - - - - - - - - - - - - - - -

  test '528',
  %w( created text files are returned in json payload ) do
    cyber_dojo_sh = 'echo "xxx" > newfile.txt'
    in_kata_as('salmon') {
      named_args = {
        changed_files: { 'cyber-dojo.sh' => cyber_dojo_sh }
      }
      run_cyber_dojo_sh(named_args)
    }
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
