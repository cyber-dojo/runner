require_relative 'test_base'
require_relative '../../src/shell_error'

class ShellTest < TestBase

  def self.hex_prefix
    'C894D'
  end

  # - - - - - - - - - - - - - - - - -
  # shell.exec(command)
  # - - - - - - - - - - - - - - - - -

  test '243',
  %w( when exec(command) raises an expeption,
      then the exception is translated into a ShellError,
      it logs nothing
  ) do
    error = assert_raises(ShellError) {
      shell.exec('xxx Hello')
    }
    expected = {
      'command' => 'xxx Hello',
      'error' => 'No such file or directory - xxx'
    }
    assert_equal expected, JSON.parse(error.message)
    assert_equal [], log.messages
  end

  # - - - - - - - - - - - - - - - - -

  test '244',
  %w( when exec(command) is zero,
      it does not raise,
      it returns [stdout,stderr,status],
      it logs nothing
  ) do
    stdout,stderr,status = shell.exec('printf Hello')
    assert_equal 'Hello', stdout
    assert_equal '', stderr
    assert_equal 0, status
    assert_equal [], log.messages
  end

  # - - - - - - - - - - - - - - - - -

  test '245',
  %w( when exec(command) is non-zero,
      it does not raise,
      it returns [stdout,stderr,status],
      it logs [command,stdout,stderr,status]
  ) do
    command = 'printf Bye && false'
    stdout,stderr,status = shell.exec(command)
    assert_equal 'Bye', stdout
    assert_equal '', stderr
    assert_equal 1, status
    expected = {
      'command' => command,
      'stdout'  => 'Bye',
      'stderr'  => '',
      'status'  => 1
    }
    assert_equal expected, JSON.parse(log.messages[0])
  end

  # - - - - - - - - - - - - - - - - -
  # shell.assert(command)
  # - - - - - - - - - - - - - - - - -

  test '247',
  %w( when assert(command) has status of zero,
      it returns stdout,
      it logs nothing
  ) do
    stdout = shell.assert('printf Hello')
    assert_equal 'Hello', stdout
    assert_equal [], log.messages
  end

  # - - - - - - - - - - - - - - - - -

  test '248',
  %w( when assert(command) has a status of non-zero,
      it raises a ShellError holding [command],
      it logs [command,stdout,stderr,status]
  ) do
    command = 'printf Hello && false'
    error = assert_raises(ShellError) {
      shell.assert(command)
    }
    assert_equal "printf Hello && false", error.message

    expected = {
      'command' => command,
      'stdout'  => 'Hello',
      'stderr'  => '',
      'status'  => 1
    }
    assert_equal expected, JSON.parse(log.messages[0])
  end

  # - - - - - - - - - - - - - - - - -

  test '249',
  %w( when assert(command) raises
      it translates the exception into a ShellError with the command and original message,
      it logs nothing
  ) do
    error = assert_raises(ShellError) {
      shell.assert('xxx Hello')
    }
    expected = {
      'command' => 'xxx Hello',
      'error' => 'No such file or directory - xxx'
    }
    assert_equal expected, JSON.parse(error.message)
    assert_equal [], log.messages
  end

  # - - - - - - - - - - - - - - - - -

  def shell
    external.shell
  end

  def log
    external.log
  end

end
