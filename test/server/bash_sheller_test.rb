# frozen_string_literal: true
require_relative 'test_base'

class BashShellerTest < TestBase

  def self.id58_prefix
    'C89'
  end

  # - - - - - - - - - - - - - - - - -

  test '243',
  %w( when capture(command) raises an exception,
      then the exception is untouched
      then nothing is logged
  ) do
    error = assert_raises(Errno::ENOENT) { sheller.capture('xxx Hello') }
    expected = 'No such file or directory - xxx'
    assert_equal expected, error.message, :error_message
    assert log.empty?, log
  end

  # - - - - - - - - - - - - - - - - -

  test '244',
  %w(
  when capture(command)'s status is zero,
  it logs nothing,
  it returns [stdout,stderr,status],
  ) do
    stdout,stderr,status = sheller.capture('printf Specs')
    assert_equal 'Specs', stdout, :stdout
    assert_equal '', stderr, :stderr
    assert_equal 0, status, :status
    assert log.empty?, log
  end

  # - - - - - - - - - - - - - - - - -

  test '245',
  %w(
  when capture(command)'s status is non-zero,
  it does not raise,
  it logs [command,stdout,stderr,status],
  it returns [stdout,stderr,status],
  ) do
    command = 'printf Croc && >&2 printf Fish && false'
    stdout,stderr,status = sheller.capture(command)
    assert_equal 'Croc', stdout, :stdout
    assert_equal 'Fish', stderr, :stderr
    assert_equal 1, status, :status
    assert logged?("command:#{command}:"), log
    assert logged?('stdout:Croc:'), log
    assert logged?('stderr:Fish:'), log
    assert logged?('status:1:'), log
  end

  private

  def sheller
    context.sheller
  end

end
