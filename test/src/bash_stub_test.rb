require_relative 'test_base'
require_relative 'bash_stub'

class BashStubTest < TestBase

  def self.hex_prefix
    'F03'
  end

  def hex_setup
    @bash = BashStub.new
  end

  attr_reader :bash

  # - - - - - - - - - - - - - - -

  test '4A5',
  %w( teardown does not raise
      when no run()s are stubbed
      and no run()s are made
  ) do
    bash.teardown
  end

  # - - - - - - - - - - - - - - -

  test '652',
  %w( run() raises when run() is not stubbed
  ) do
    assert_raises { bash.run(pwd) }
  end

  # - - - - - - - - - - - - - - -

  test '181',
  %w( run() raises when run() is stubbed but for a different command
  ) do
    bash.stub_run(pwd, wd, stderr='', success)
    assert_raises { bash.run(not_pwd = "cd #{wd}") }
  end

  # - - - - - - - - - - - - - - -

  test 'B4E',
  %w( teardown does not raise
      when one run() is stubbed
      and a matching run() is made
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
      when a run() is stubbed
      and no run() is made
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
