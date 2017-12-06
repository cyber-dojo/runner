require_relative 'test_base'
require_relative 'bash_stubber'

class BashStubberTest < TestBase

  def self.hex_prefix
    'F03E2'
  end

  def hex_setup
    @bash = BashStubber.new
  end

  attr_reader :bash

  # - - - - - - - - - - - - - - -

  test '4A5',
  %w( teardown does not raise
      when no mock_exec's are setup
      and no exec's are made
  ) do
    bash.teardown
  end

  # - - - - - - - - - - - - - - -

  test '652',
  %w( exec(command) raises
      when an exec is made
      and there are no mock_exec's
  ) do
    assert_raises { bash.run(pwd) }
  end

  # - - - - - - - - - - - - - - -

  test '181',
  %w( exec(command) raises
      when mock_exec is for a different command
  ) do
    bash.stub_run(pwd, wd, stderr='', success)
    assert_raises { bash.run(not_pwd = "cd #{wd}") }
  end

  # - - - - - - - - - - - - - - -

  test 'B4E',
  %w( teardown does not raise
      when one mock_exec is setup
      and a matching exec is made
  ) do
    bash.stub_run(pwd, wd, stderr='', success)
    stdout,stderr,status = bash.run('pwd')
    assert_equal wd, stdout
    assert_equal '', stderr
    assert_equal success, status
    bash.teardown
  end

  # - - - - - - - - - - - - - - -

  test 'D0C',
  %w( teardown raises
      when one mock_exec setup
      and no calls are made
  ) do
    bash.stub_run(pwd, wd, stderr='', success)
    assert_raises { bash.teardown }
  end

  # - - - - - - - - - - - - - - -

  test '470',
  %w( teardown does not raise
      when there is an uncaught exception
  ) do
    bash.stub_run(pwd, wd, stderr='', success)
    error = assert_raises {
      begin
        raise 'forced'
      ensure
        bash.teardown
      end
    }
    assert_equal 'forced', error.message
  end

  # - - - - - - - - - - - - - - -

  test '4FE',
  %w( shell.assert does not raise
      when status is zero
  ) do
    ms.bash = BashStubber.new
    ms.bash.stub_run('true', 'so', 'se', 0)
    assert_equal 'so', shell.assert('true')
  end

  # - - - - - - - - - - - - - - -

  test '4FF',
  %w( shell.assert raises
      when status is non-zero
  ) do
    ms.bash = BashStubber.new
    ms.bash.stub_run('false', '', '', 1)
    error = assert_raises(ShellError) { shell.assert('false') }
  end

  private # = = = = = = = = = = = = = = =

  def pwd
    'pwd'
  end

  def wd
    '/Users/jonjagger/repos/web'
  end

  def success
    0
  end

end
