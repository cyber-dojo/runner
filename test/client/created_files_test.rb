# frozen_string_literal: true
require_relative '../test_base'

module Client
  class CreatedFilesTest < TestBase

    def self.id58_prefix
      '2D1'
    end

    # - - - - - - - - - - - - - - - - -

    c_assert_test '160',
    %w( round-tripping: example of no file changes ) do
      set_context
      run_cyber_dojo_sh
      assert_equal({}, created)
      assert_equal([], deleted)
      assert_equal({}, changed)
    end

    # - - - - - - - - - - - - - - - - -

    c_assert_test '161',
    %w( created binary files are not returned in json payload
    but created text files are ) do
      set_context
      exec([
        'make',
        'file --mime-encoding test',
        'echo -n "xxx" > newfile.txt',
      ].join("\n"))
      assert stdout.include?('test: binary'), stdout # file --mime-encoding
      assert_equal({ 'newfile.txt' => intact('xxx') }, created)
      assert_equal([], deleted)
      assert_equal({}, changed)
    end

    # - - - - - - - - - - - - - - - - -

    test '162',
    %w( created text files in sub-dirs are returned in json payload ) do
      set_context
      exec('mkdir sub && echo -n "yyy" > sub/newfile.txt')
      assert_equal({ 'sub/newfile.txt' => intact('yyy') }, created)
      assert_equal([], deleted)
      assert_equal({}, changed)
    end

    # - - - - - - - - - - - - - - - - -

    test '163',
    %w( changed text files are returned in json payload ) do
      set_context
      exec('echo -n "jjj" > hiker.h')
      assert_equal({}, created)
      assert_equal([], deleted)
      assert_equal({ 'hiker.h' => intact('jjj')}, changed)
    end

    # - - - - - - - - - - - - - - - - -

    test '164',
    %w( created empty text files is returned in json payload ) do
      set_context
      exec('touch empty.file')
      assert_equal({ 'empty.file' => intact('')}, created)
      assert_equal([], deleted)
      assert_equal({}, changed)
    end

    private

    def exec(script)
      run_cyber_dojo_sh(
        changed: {
          'cyber-dojo.sh' => script
        }
      )
    end

  end
end
