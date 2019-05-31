require_relative 'test_base'

class RoundTripTest < TestBase

  def self.hex_prefix
    '2D1'
  end

  # - - - - - - - - - - - - - - - - -

  test '160',
  %w( [Ubuntu] round-tripping: example of no file changes ) do
    # Using [Ubuntu] because that's Perl-testsimple which does
    # not generated any extra text files. In contrast, Alpine is
    # CSharp-NUnit which does generate an .xml text file.
    run_cyber_dojo_sh
    assert_equal({}, created)
    assert_equal([], deleted)
    assert_equal({}, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test '161',
  %w( [C,assert] created binary files are not returned in json payload
  but created text files are ) do
    exec([
      'make',
      'file --mime-encoding test',
      'echo -n "xxx" > newfile.txt',
    ].join("\n"))
    assert stdout.include?('test: binary') # file --mime-encoding
    assert_equal({ 'newfile.txt' => intact('xxx') }, created)
    assert_equal([], deleted)
    assert_equal({}, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test '162',
  %w( created text files in sub-dirs are returned in json payload ) do
    exec('mkdir sub && echo -n "yyy" > sub/newfile.txt')
    assert_equal({ 'sub/newfile.txt' => intact('yyy') }, created)
    assert_equal([], deleted)
    assert_equal({}, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test '163',
  %w( [C,assert] changed text files are returned in json payload ) do
    exec('echo -n "jjj" > hiker.h')
    assert_equal({}, created)
    assert_equal([], deleted)
    assert_equal({ 'hiker.h' => intact('jjj')}, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test '164',
  %w( [C,assert] created empty text files is returned in json payload ) do
    exec('touch empty.file')
    assert_equal({ 'empty.file' => intact('')}, created)
    assert_equal([], deleted)
    assert_equal({}, changed)
  end

  private

  def exec(script)
    named_args = {
      changed_files: {
        'cyber-dojo.sh' => script
      }
    }
    run_cyber_dojo_sh(named_args)
  end

  # - - - - - - - - - - - - - - - - -

  def intact(content)
    { 'content' => content, 'truncated' => false }
  end

end
