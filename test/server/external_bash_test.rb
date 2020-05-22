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

  # - - - - - - - - - - - - - - - - -
  # bash.assert(command)
  # - - - - - - - - - - - - - - - - -

  test 'f46',
  %w(
  when assert(command)'s
  status is zero,
  and stderr is empty,
  it returns stdout,
  it logs nothing
  ) do
    stdout = bash.assert('printf Hello')
    assert_equal 'Hello', stdout, :stdout
    assert log.empty?, log
  end

  # - - - - - - - - - - - - - - - - -

  test 'f47',
  %w(
  when assert(command)'s
  status is zero,
  and stderr is not empty,
  it returns stdout,
  it logs the assert
  ) do
    command = 'printf Welcome && >&2 printf Bonjour && true'
    stdout = bash.assert(command)
    assert_equal 'Welcome', stdout, :stdout
    assert_log_contains(command, 'Welcome', 'Bonjour', 0)
  end

  # - - - - - - - - - - - - - - - - -

  test 'f48', %w(
  when assert(command)'s
  status is non-zero,
  and stderr is not empty,
  it logs [command,stdout,stderr,status],
  it raises a ExternalBash::AssertError holding [command,stdout,stderr,status],
  ) do
    command = 'printf Pencil && >&2 printf Jello && false'
    error = assert_raises(ExternalBash::AssertError) { bash.assert(command) }
    assert_log_contains(command, 'Pencil', 'Jello', 1)
    assert_error_contains(error, command, 'Pencil', 'Jello', 1)
  end

  # - - - - - - - - - - - - - - - - -

  test 'f49', %w(
  when assert(command) raises
  the exception is untouched,
  it logs nothing
  ) do
    error = assert_raises(Errno::ENOENT) { bash.assert('xxx Hello') }
    expected = 'No such file or directory - xxx'
    assert_equal expected, error.message, :error_message
    assert log.empty?, log
  end

  private

  def assert_error_contains(error, command, stdout, stderr, status)
    refute_nil error
    refute_nil error.message
    json = JSON.parse(error.message)
    assert_error_contains_key(error, json, 'command', command)
    assert_error_contains_key(error, json, 'stdout', stdout)
    assert_error_contains_key(error, json, 'stderr', stderr)
    assert_error_contains_key(error, json, 'status', status)
  end

  def assert_error_contains_key(error, json, key, value)
    diagnostic = "JSON(error.message) does not contain key:#{key}:\n:#{error.message}:"
    assert json.has_key?(key), diagnostic
    assert_equal value, json[key], error.message
  end

  # - - - - - - - - - - - - - - - - - - - - - - - -

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
