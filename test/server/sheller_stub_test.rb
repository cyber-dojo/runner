# frozen_string_literal: true
require_relative 'test_base'
require_relative 'sheller_stub'

class ShellerStubTest < TestBase

  def self.id58_prefix
    'F03'
  end

  def id58_setup
    @sheller = ShellerStub.new
  end

  attr_reader :sheller

  # - - - - - - - - - - - - - - -

  test '4A5',
  %w(
  teardown does not raise
  when no execute()s are stubbed
  and no execute()s are made
  ) do
    sheller.teardown
  end

  # - - - - - - - - - - - - - - -

  test '652',
  %w( execute() raises when execute() is not stubbed
  ) do
    assert_raises { sheller.execute(pwd) }
  end

  # - - - - - - - - - - - - - - -

  test '181',
  %w( execute() raises when execute() is stubbed but for a different command
  ) do
    sheller.stub_execute(pwd, wd, stderr='', success)
    assert_raises { sheller.execute(not_pwd = "cd #{wd}") }
  end

  # - - - - - - - - - - - - - - -

  test 'B4E',
  %w(
  teardown does not raise
  when one execute() is stubbed
  and a matching execute() is made
  ) do
    sheller.stub_execute(pwd, wd, stderr='', success)
    stdout,stderr,status = sheller.execute('pwd')
    assert_equal wd, stdout
    assert_equal '', stderr
    assert_equal success, status
    sheller.teardown
  end

  # - - - - - - - - - - - - - - -

  test 'D0C',
  %w(
  teardown raises
  when a execute() is stubbed
  and no execute() is made
  ) do
    sheller.stub_execute(pwd, wd, stderr='', success)
    assert_raises { sheller.teardown }
  end

  # - - - - - - - - - - - - - - -

  test '470',
  %w( teardown does not raise
      when there is an uncaught exception
  ) do
    sheller.stub_execute(pwd, wd, stderr='', success)
    error = assert_raises {
      begin
        raise 'forced'
      ensure
        sheller.teardown
      end
    }
    assert_equal 'forced', error.message
  end

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
