require_relative 'test_base'
require_relative 'logger_spy'

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
    stdout = shell.assert('echo Hello')
    assert_equal "Hello\n", stdout
    assert_log []
  end

  # - - - - - - - - - - - - - - - - -

  test '14B',
  'assert(cmd) logs and raises when command fails' do
    error = assert_raises(ArgumentError) {
      shell.assert('false')
    }
    assert_log [
      line,
      'COMMAND:false',
      'STATUS:1',
      'STDOUT:',
      'STDERR:'
    ]
    error = assert_raises(ArgumentError) {
      shell.assert('sed salmon')
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
    stdout,stderr,status = shell.exec('echo Hello')
    assert_equal 0, status
    assert_equal "Hello\n", stdout
    assert_equal '', stderr
    assert_log []
  end

  # - - - - - - - - - - - - - - - - -

  test '490',
  'exec(cmd) failure (no output) is logged' do
    stdout,stderr,status = shell.exec('false')
    assert_equal 1, status
    assert_equal '', stdout
    assert_equal '', stderr
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
    stdout,stderr,status = shell.exec('sed salmon')
    assert_equal 1, status
    assert_equal '', stdout
    assert_equal "sed: unmatched 'a'\n", stderr
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
    error = assert_raises { shell.exec('zzzz') }
    assert_equal 'Errno::ENOENT', error.class.name
    assert_log [
      line,
      'COMMAND:zzzz',
      'RAISED-CLASS:Errno::ENOENT',
      'RAISED-TO_S:No such file or directory - zzzz'
    ]
  end

  # - - - - - - - - - - - - - - - - -

  def assert_log(expected)
    assert_equal expected, log.spied
  end

  def line
    '-' * 40
  end

end
