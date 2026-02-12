require_relative '../test_base'

class BashShellerStubTest < TestBase
  def id58_setup
    @sheller = BashShellerStub.new
  end

  attr_reader :sheller

  # - - - - - - - - - - - - - - -

  test 'F034A5', %w(
  | teardown does not raise
  | when no capture()s are stubbed
  | and no capture()s are made
  ) do
    sheller.teardown
  end

  # - - - - - - - - - - - - - - -

  test 'F03652', %w(
  | capture() raises when capture() is not stubbed
  ) do
    assert_raises { sheller.capture(pwd) }
  end

  # - - - - - - - - - - - - - - -

  test 'F03181', %w(
  | capture() raises when capture() is stubbed but for a different command
  ) do
    sheller.capture(pwd) { [wd, stderr = '', success] }
    assert_raises { sheller.capture(not_pwd = "cd #{wd}") }
  end

  # - - - - - - - - - - - - - - -

  test 'F03B4E', %w(
  | teardown does not raise
  | when one capture() is stubbed
  | and a matching capture() is made
  ) do
    sheller.capture(pwd) { [wd, stderr = '', success] }
    stdout, stderr, status = sheller.capture('pwd')
    assert_equal wd, stdout
    assert_equal '', stderr
    assert_equal success, status
    sheller.teardown
  end

  # - - - - - - - - - - - - - - -

  test 'F03D0C', %w(
  | teardown raises
  | when a capture() is stubbed
  | and no capture() is made
  ) do
    sheller.capture(pwd) { [wd, stderr = '', success] }
    assert_raises { sheller.teardown }
  end

  # - - - - - - - - - - - - - - -

  test 'F03470', %w[
  | teardown does not raise
  | when there is an uncaught exception
  ] do
    sheller.capture(pwd) { [wd, stderr = '', success] }
    error = assert_raises do
      raise 'forced'
    ensure
      sheller.teardown
    end
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
