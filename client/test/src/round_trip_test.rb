require_relative 'test_base'

class RoundTripTest < TestBase

  def self.hex_prefix
    '2D128'
  end

  # - - - - - - - - - - - - - - - - -

  test '160',
  %w( [Ubuntu] round-tripping: example of no file changes ) do
    # Using [Ubuntu] because that's Perl-testsimple which does
    # not generated any text files. In contrast, Alpine is
    # CSharp-NUnit which does generate an .xml text file.
    in_kata_as('salmon') { run_cyber_dojo_sh }
    assert_equal({}, new_files)
    assert_equal({}, deleted_files)
    assert_equal({}, changed_files)
  end

  # - - - - - - - - - - - - - - - - -

  test '161',
  %w( [C,assert] created binary files are not returned in json payload
  but created text files are ) do
    in_kata_as_salmon_run([
      'make',
      'file --mime-encoding test',
      'echo "xxx" > newfile.txt',
    ].join("\n"))
    assert stdout.include?('test: binary') # file --mime-encoding
    assert_equal({ 'newfile.txt' => "xxx\n"}, new_files)
    assert_equal({}, deleted_files)
    assert_equal({}, changed_files)
  end

  # - - - - - - - - - - - - - - - - -

  test '162',
  %w( created text files in sub-dirs are returned in json payload ) do
    in_kata_as_salmon_run('mkdir sub && echo "xxx" > sub/newfile.txt')
    assert_equal({ 'sub/newfile.txt' => "xxx\n"}, new_files)
    assert_equal({}, deleted_files)
    assert_equal({}, changed_files)
  end

  # - - - - - - - - - - - - - - - - -

  test '163',
  %w( [C,assert] changed text files are returned in json payload ) do
    in_kata_as_salmon_run('echo "xxx" > hiker.h')
    assert_equal({}, new_files)
    assert_equal({}, deleted_files)
    assert_equal({ 'hiker.h' => "xxx\n"}, changed_files)
  end

  # - - - - - - - - - - - - - - - - -

  def in_kata_as_salmon_run(script)
    in_kata_as('salmon') {
      named_args = {
        changed_files: {
          'cyber-dojo.sh' => script
        }
      }
      run_cyber_dojo_sh(named_args)
    }
  end

end

