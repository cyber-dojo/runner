require_relative 'test_base'

class ShellTest < TestBase

  def self.hex_prefix
    'C894D'
  end

  # - - - - - - - - - - - - - - - - -
  # shell.exec(command)
  # - - - - - - - - - - - - - - - - -

  test '243', %w( when exec(command) raises
    a ShellError holding the command and original exception message is raised
  ) do
    error = assert_raises(ShellError) {
      shell.exec('xxx Hello')
    }
    expected = {
      command:'xxx Hello',
      message:'No such file or directory - xxx'
    }
    assert_equal expected, error.args
  end

  # - - - - - - - - - - - - - - - - -

  test '244',
  %w( when exec(command) is zero,
      it returns [stdout,stderr,status]
  ) do
    stdout,stderr,status = shell.exec('printf Hello')
    assert_equal 'Hello', stdout
    assert_equal '', stderr
    assert_equal 0, status
  end

  # - - - - - - - - - - - - - - - - -

  test '245',
  %w( when exec(command) is non-zero,
      it returns [stdout,stderr,status]
  ) do
    stdout,stderr,status = shell.exec('printf Bye && false')
    assert_equal 'Bye', stdout
    assert_equal '', stderr
    assert_equal 1, status
  end

  # - - - - - - - - - - - - - - - - -
  # shell.assert(command)
  # - - - - - - - - - - - - - - - - -

  test '247',
  %w( when assert(command) has status of zero,
      stdout is returned ) do
    stdout = shell.assert('printf Hello')
    assert_equal 'Hello', stdout
  end

  # - - - - - - - - - - - - - - - - -

  test '248',
  %w( when assert(command) has a status of non-zero,
      a ShellError holding the command,stderr,stderr, and status is raised
  ) do
    error = assert_raises(ShellError) {
      shell.assert('printf Hello && false')
    }
    expected = {
      command:'printf Hello && false',
      stdout:'Hello',
      stderr:'',
      status:1
    }
    assert_equal expected, error.args
  end

  # - - - - - - - - - - - - - - - - -

  test '246',
  %w( when assert(command) raises
      a ShellError holding the command and original exception message is raised
  ) do
    error = assert_raises(ShellError) {
      shell.assert('xxx Hello')
    }
    expected = {
      command:'xxx Hello',
      message:'No such file or directory - xxx'
    }
    assert_equal expected, error.args
  end

  # - - - - - - - - - - - - - - - - -

  def shell
    Shell.new(external)
  end

end
