require_relative 'test_base'

class RoundTripTest < TestBase

  def self.hex_prefix
    'ECFA3'
  end

  # - - - - - - - - - - - - - - - - -

  test '525',
  %w( sent files are returned in json payload ready to round-trip ) do
    [ :Alpine, :Ubuntu, :Debian ].each do |name|
      os = name
      in_kata_as('salmon') { assert_cyber_dojo_sh('ls') }
      assert_hash_equal(@previous_files, files)
    end
  end

  # - - - - - - - - - - - - - - - - -

  test '528',
  %w( [C,assert] created binary files are not returned in json payload
  but created text files are ) do
    script = [
      'make >/dev/null',
      'file --mime-encoding test',
      'echo "xxx" > newfile.txt',
    ].join(';')

    in_kata_as('salmon') { assert_cyber_dojo_sh(script) }

    assert stdout.include?('test: binary') # file --mime-encoding
    expected = starting_files
    expected['cyber-dojo.sh'] = script
    expected['newfile.txt'] = "xxx\n"
    assert_hash_equal(expected, files)
  end

  # - - - - - - - - - - - - - - - - -

  test '529',
  %w( created text files in sub-dirs are returned in json payload ) do
    script = [
      'mkdir sub',
      'echo "xxx" > sub/newfile.txt'
    ].join(';')

    [ :Alpine, :Ubuntu, :Debian ].each do |name|
      os = name
      in_kata_as('salmon') { assert_cyber_dojo_sh(script) }
      expected = starting_files
      expected['cyber-dojo.sh'] = script
      expected['sub/newfile.txt'] = "xxx\n"
      assert_hash_equal(expected, files)
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
