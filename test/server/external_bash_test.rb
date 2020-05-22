# frozen_string_literal: true
require_relative 'test_base'

class ExternalBashTest < TestBase

  def self.id58_prefix
    'C89'
  end

  def bash
    externals.bash
  end

  def log
    externals.logger.log
  end

  # - - - - - - - - - - - - - - - - -
  # bash.exec(command)
  # - - - - - - - - - - - - - - - - -

  test '243',
  %w( when exec(command) raises an exception,
      then the exception is untouched
      then nothing is logged
  ) do
    error = assert_raises(Errno::ENOENT) { bash.exec('xxx Hello') }
    expected = 'No such file or directory - xxx'
    assert_equal expected, error.message, :error_message
    assert log.empty?, log
  end

  # - - - - - - - - - - - - - - - - -

  test '244',
  %w(
  when exec(command)'s
  status is zero,
  and stderr is empty,
  it does not raise,
  it returns [stdout,stderr,status],
  it logs nothing
  ) do
    stdout,stderr,status = bash.exec('printf Hello')
    assert_equal 'Hello', stdout, :stdout
    assert_equal '', stderr, :stderr
    assert_equal 0, status, :status
    assert log.empty?, log
  end

  # - - - - - - - - - - - - - - - - -

  test '245',
  %w(
  when exec(command)'s
  status is non-zero,
  it does not raise,
  it returns [stdout,stderr,status],
  it logs [command,stdout,stderr,status]
  ) do
    command = 'printf Bye && false'
    stdout,stderr,status = bash.exec(command)
    assert_equal 'Bye', stdout, :stdout
    assert_equal '', stderr, :stderr
    assert_equal 1, status, :status

    assert_log_contains('command', command)
    assert_log_contains('stdout', 'Bye')
    assert_log_contains('stderr', '')
    assert_log_contains('status', 1)
  end

  # - - - - - - - - - - - - - - - - -

  test '246',
  %w(
  when exec(command)'s
  stderr is not empty,
  it does not raise,
  it returns [stdout,stderr,status],
  it logs [command,stdout,stderr,status]
  ) do
    command = '>&2 printf Bye && true'
    stdout,stderr,status = bash.exec(command)
    assert_equal '', stdout, :stdout
    assert_equal 'Bye', stderr, :stderr
    assert_equal 0, status, :status

    assert_log_contains('command', command)
    assert_log_contains('stdout', '')
    assert_log_contains('stderr', 'Bye')
    assert_log_contains('status', 0)
  end

  # - - - - - - - - - - - - - - - - -
  # bash.assert(command)
  # - - - - - - - - - - - - - - - - -

=begin
  test 'f47',
  %w( when assert(command) has status of zero,
      it returns stdout,
      it logs nothing
  ) do
    stdout = bash.assert('printf Hello')
    assert_equal 'Hello', stdout, :stdout
    assert log.empty?, log
  end

  # - - - - - - - - - - - - - - - - -

  test 'f48',
  %w( when assert(command) has a status of non-zero,
      it raises a ShellAssertError holding [command,stdout,stderr,status],
      it logs [command,stdout,stderr,status]
  ) do
    command = 'printf Hello && false'
    log = with_captured_log {
      error = assert_raises(ShellAssertError) { shell.assert(command) }
      assert_error_contains(error, 'command', command)
      assert_error_contains(error, 'stdout', 'Hello')
      assert_error_contains(error, 'stderr', '')
      assert_error_contains(error, 'status', 1)
    }
    assert_log_contains(log, 'command', command)
    assert_log_contains(log, 'stdout', 'Hello')
    assert_log_contains(log, 'stderr', '')
    assert_log_contains(log, 'status', 1)
  end

  # - - - - - - - - - - - - - - - - -

  test 'f49', %w(
  when assert(command) raises
  the exception is untouched,
  it logs nothing
  ) do
    log = with_captured_log {
      error = assert_raises(Errno::ENOENT) { shell.assert('xxx Hello') }
      expected = 'No such file or directory - xxx'
      assert_equal expected, error.message, :error_message
    }
    assert_equal '', log, :log
  end
=end

  private

  def assert_log_contains(key, value)
    refute_nil log
    diagnostic = "log does not contain  #{key}:#{value}\n#{log}"
    assert log.include?("#{key}:#{value}:"), diagnostic
  end

end
