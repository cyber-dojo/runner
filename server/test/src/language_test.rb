require_relative 'test_base'

class LanguageTest < TestBase

  def self.hex_prefix
    '9D930'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '76D',
  '[gcc,assert] runs' do
    sssc_run({ visible_files: read_files })
    refute_colour timed_out
    assert_stderr_include "[makefile:14: test.output] Aborted"
    assert_stderr_include 'Assertion failed: answer() == 42'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - -

  test '358',
  '[Java,Cucumber] runs' do
    sssc_run({ visible_files: read_files })
    refute_colour timed_out
    assert_stdout_include '1 Scenarios (1 failed)'
    assert_stderr ''
  end

end

