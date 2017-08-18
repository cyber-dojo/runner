require_relative 'test_base'

class LanguageTest < TestBase

  def self.hex_prefix
    '9D930'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '76D',
  '[gcc,assert] runs' do
    sss_run({ visible_files: read_files })
    assert_stdout "makefile:14: recipe for target 'test.output' failed\n"
    assert_stderr_include 'Assertion failed: answer() == 42'
    assert_status 2
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '358',
  '[Java,Cucumber] runs' do
    sss_run({ visible_files: read_files })
    assert_stdout_include '1 Scenarios (1 failed)'
    assert_stderr ''
    assert_status 1
  end

end

