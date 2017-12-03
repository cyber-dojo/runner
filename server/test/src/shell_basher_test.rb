require_relative 'test_base'
require_relative '../../src/runner_error'

class ShellBasherTest < TestBase

  def self.hex_prefix
    'C894D'
  end

  # - - - - - - - - - - - - - - - - -
  # shell.exec(cmd)
  # - - - - - - - - - - - - - - - - -

  test '243', %w( when exec(cmd) raises
    the exception info is in the exception object
    and is not logged
  ) do
    error = assert_raises(RunnerError) {
      shell.exec('xxx Hello')
    }
    assert_equal({
        'command':'shell.exec("xxx Hello")',
        'message':'No such file or directory - xxx'
      }, error.info);
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  test '244',
  %w( when exec(cmd) is zero,
      it returns [stdout,stderr,status]
      and does not log ) do
    stdout,stderr,status = shell.exec('printf Hello')
    assert_equal 'Hello', stdout
    assert_equal '', stderr
    assert_equal 0, status
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  test '245',
  %w( when exec(cmd) is non-zero,
      it returns [stdout,stderr,status]
      and logs ) do
    stdout,stderr,status = shell.exec('printf Bye && false')
    assert_equal 'Bye', stdout
    assert_equal '', stderr
    assert_equal 1, status

    assert_logged({
      'command':'shell.exec("printf Bye && false")',
      'stdout':'Bye',
      'stderr':'',
      'status':1
    })
  end

  # - - - - - - - - - - - - - - - - -
  # shell.assert(cmd)
  # - - - - - - - - - - - - - - - - -

  test '246',
  %w( when assert(cmd) raises
      the exception info is in the exception object
      and is not logged
  ) do
    error = assert_raises(RunnerError) {
      shell.assert('xxx Hello')
    }
    assert_equal({
        'command':'shell.assert("xxx Hello")',
        'message':'No such file or directory - xxx'
      }, error.info);
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  test '247',
  %w( when assert(cmd) is zero, nothing is logged, stdout is returned ) do
    stdout = shell.assert('printf Hello')
    assert_equal 'Hello', stdout
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  test '248',
  %w( when assert(cmd) is non-zero,
      exception is raised,
      the exception info is in the exception object
      and is not logged
  ) do
    error = assert_raises(RunnerError) {
      shell.assert('printf Hello && false')
    }
    assert_equal({
        'command':'shell.assert("printf Hello && false")',
        'stdout':'Hello',
        'stderr':'',
        'status':1
      }, error.info);
    assert_nothing_logged
  end

  # - - - - - - - - - - - - - - - - -

  def assert_nothing_logged
    assert_equal [], log.messages
  end

  # - - - - - - - - - - - - - - - - -

  def assert_logged(hash)
    assert_equal [hash], log.messages
  end

end
