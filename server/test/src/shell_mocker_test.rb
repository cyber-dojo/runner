require_relative 'test_base'
require_relative 'shell_mocker'

class ShellMockerTest < TestBase

  def self.hex_prefix
    'F03'
  end

  # - - - - - - - - - - - - - - -

  test 'B51',
  %w( MockSheller ctor only sets mocks=[]
      when file does not already exist
  )do
    # has to work when it is "re-created" in different threads

    hex_test_id = ENV['CYBER_DOJO_HEX_TEST_ID']
    filename = Dir.tmpdir + '/cyber_dojo_mock_sheller_' + hex_test_id + '.json'
    `rm #{filename} 2> /dev/null`

    shell_1 = ShellMocker.new(nil)
    shell_1.mock_exec(pwd, wd, stderr='', success)

    shell_2 = ShellMocker.new(nil)
    stdout,stderr,status = shell_2.exec(pwd)
    assert_equal wd, stdout
    assert_equal '', stderr
    assert_equal success, status
    shell_1.teardown
    shell_2.teardown
  end

  # - - - - - - - - - - - - - - -

  test '4A5',
  %w( teardown does not raise
      when no mock_exec's are setup
      and no exec's are made
  ) do
    shell = ShellMocker.new(nil)
    shell.teardown
  end

  # - - - - - - - - - - - - - - -

  test '652',
  %w( exec(command) raises
      when an exec is made
      and there are no mock_exec's
  ) do
    shell = ShellMocker.new(nil)
    assert_raises { shell.exec(pwd) }
  end

  # - - - - - - - - - - - - - - -

  test '181',
  %w( exec(command) raises
      when mock_exec is for a different command
  ) do
    shell = ShellMocker.new(nil)
    shell.mock_exec(pwd, wd, stderr='', success)
    assert_raises { shell.exec(not_pwd = "cd #{wd}") }
  end

  # - - - - - - - - - - - - - - -

  test 'B4E',
  %w( teardown does not raise
      when one mock_exec is setup
      and a matching exec is made
  ) do
    shell = ShellMocker.new(nil)
    shell.mock_exec(pwd, wd, stderr='', success)
    stdout,stderr,status = shell.exec('pwd')
    assert_equal wd, stdout
    assert_equal '', stderr
    assert_equal success, status
    shell.teardown
  end

  # - - - - - - - - - - - - - - -

  test 'D0C',
  %w( teardown raises
      when one mock_exec setup
      and no calls are made
  ) do
    shell = ShellMocker.new(nil)
    shell.mock_exec(pwd, wd, stderr='', success)
    assert_raises { shell.teardown }
  end

  # - - - - - - - - - - - - - - -

  test '470',
  %w( teardown does not raise
      when there is an uncaught exception
  ) do
    shell = ShellMocker.new(nil)
    shell.mock_exec(pwd, wd, stderr='', success)
    error = assert_raises {
      begin
        fail 'forced'
      ensure
        shell.teardown
      end
    }
    assert_equal 'forced', error.message
  end

  # - - - - - - - - - - - - - - -

  test '4FF',
  %w( assert_exec raises
      when status is non-zero
  ) do
    shell = ShellMocker.new(nil)
    shell.mock_exec('false', '', '', 1)
    error = assert_raises { shell.assert_exec('false') }
    assert_equal 'command:false', error.message
  end

  # - - - - - - - - - - - - - - -

  test '3BE',
  %w( success is zero ) do
    shell = ShellMocker.new(nil)
    assert_equal 0, shell.success
  end

  # - - - - - - - - - - - - - - -

  private

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
