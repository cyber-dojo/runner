# frozen_string_literal: true
require_relative 'test_base'

class ExternalBashTest < TestBase

  def self.id58_prefix
    'C89'
  end

  def bash
    externals.bash
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
    stdout,stderr,status = bash.exec('printf Specs')
    assert_equal 'Specs', stdout, :stdout
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
    command = 'printf Croc && >&2 printf Fish && false'
    stdout,stderr,status = bash.exec(command)
    assert_equal 'Croc', stdout, :stdout
    assert_equal 'Fish', stderr, :stderr
    assert_equal 1, status, :status
    assert_log_contains(command, 'Croc', 'Fish', 1)
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
    command = 'printf Rabbit && >&2 printf Mole && true'
    stdout,stderr,status = bash.exec(command)
    assert_equal 'Rabbit', stdout, :stdout
    assert_equal 'Mole', stderr, :stderr
    assert_equal 0, status, :status
    assert_log_contains(command, 'Rabbit', 'Mole', 0)
  end

  private

  def assert_log_contains(command, stdout, stderr, status)
    refute_nil log
    assert_log_contains_key('command', command)
    assert_log_contains_key('stdout', stdout)
    assert_log_contains_key('stderr', stderr)
    assert_log_contains_key('status', status)
  end

  def assert_log_contains_key(key, value)
    diagnostic = "log does not contain  #{key}:#{value}:\n:log:#{log}:"
    assert log.include?("#{key}:#{value}:"), diagnostic
  end

end
