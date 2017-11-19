require_relative 'test_base'
require_relative '../../src/logger_spy'

class ShellBasherTest < TestBase

  def self.hex_prefix
    'C89'
  end

  def hex_setup
    @log = LoggerSpy.new(nil)
  end

  attr_reader :log

  # - - - - - - - - - - - - - - - - -

  test '243', %w(
    when assert(cmd) status is zero
    it returns stdout
    and logs nothing
  ) do
    shell_assert('echo Hello')
    assert_stdout "Hello\n"
    assert_log []
  end

  # - - - - - - - - - - - - - - - - -

  test '14B',
  'assert(cmd) logs and raises when command fails' do
    error = assert_raises(ArgumentError) {
      shell_assert('false')
    }
    assert_log [
      line,
      'COMMAND:false',
      'STATUS:1',
      'STDOUT:',
      'STDERR:'
    ]
    error = assert_raises(ArgumentError) {
      shell_assert('sed salmon')
    }
    assert_log [
      line,
      'COMMAND:false',
      'STATUS:1',
      'STDOUT:',
      'STDERR:',
      line,
      'COMMAND:sed salmon',
      'STATUS:1',
      'STDOUT:',
      "STDERR:sed: unmatched 'a'\n"
    ]
  end

  # - - - - - - - - - - - - - - - - -

  test 'DBB',
  'exec(cmd) succeeds with output, no logging' do
    shell_exec('echo Hello')
    assert_status 0
    assert_stdout "Hello\n"
    assert_stderr ''
    assert_log []
  end

  # - - - - - - - - - - - - - - - - -

  test '490',
  'exec(cmd) failure (no output) is logged' do
    shell_exec('false')
    assert_status 1
    assert_stdout ''
    assert_stderr ''
    assert_log [
      line,
      'COMMAND:false',
      'STATUS:1',
      'STDOUT:',
      'STDERR:'
    ]
  end

  # - - - - - - - - - - - - - - - - -

  test '46B',
  'exec(cmd) failure (with output) is logged' do
    shell_exec('sed salmon')
    assert_status 1
    assert_stdout ''
    assert_stderr "sed: unmatched 'a'\n"
    assert_log [
      line,
      'COMMAND:sed salmon',
      'STATUS:1',
      'STDOUT:',
      "STDERR:sed: unmatched 'a'\n"
    ]
  end

  # - - - - - - - - - - - - - - - - -

  test 'AF6',
  'exec(cmd) raises with verbose output' do
    # some commands fail with simple non-zero exit status...
    # some commands fail with an exception...
    error = assert_raises { shell_exec('zzzz') }
    assert_equal 'Errno::ENOENT', error.class.name
    assert_log [
      line,
      'COMMAND:zzzz',
      'RAISED-CLASS:Errno::ENOENT',
      'RAISED-TO_S:No such file or directory - zzzz'
    ]
  end

  # - - - - - - - - - - - - - - - - -

  def shell_exec(command)
    @stdout,@stderr,@status = shell.exec(command)
  end

  def shell_assert(command)
    @stdout = shell.assert(command)
  end

  # - - - - - - - - - - - - - - - - -

  def assert_status(expected)
    assert_equal expected, @status
  end

  def assert_stdout(expected)
    assert_equal expected, @stdout
  end

  def assert_stderr(expected)
    assert_equal expected, @stderr
  end

  def assert_log(expected)
    assert_equal expected, log.spied
  end

  def line
    '-' * 40
  end

end
