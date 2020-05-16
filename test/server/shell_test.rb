# frozen_string_literal: true
require_relative 'test_base'

class ShellTest < TestBase

  def self.id58_prefix
    'C89'
  end

  def shell
    externals.shell
  end

  # - - - - - - - - - - - - - - - - -
  # shell.exec(command)
  # - - - - - - - - - - - - - - - - -

  test '243',
  %w( when exec(command) raises an exception,
      then the exception is untouched
      then nothing is logged
  ) do
    log,_ = with_captured_log {
      error = assert_raises(Errno::ENOENT) { shell.exec('xxx Hello') }
      expected = 'No such file or directory - xxx'
      assert_equal expected, error.message, :error_message
    }
    assert_equal '', log, :log
  end

  # - - - - - - - - - - - - - - - - -

  test '244',
  %w( when exec(command)'s status is zero,
      it does not raise,
      it returns [stdout,stderr,status],
      it logs nothing
  ) do
    log,_ = with_captured_log {
      stdout,stderr,status = shell.exec('printf Hello')
      assert_equal 'Hello', stdout, :stdout
      assert_equal '', stderr, :stderr
      assert_equal 0, status, :status
    }
    assert_equal '', log, :log
  end

  # - - - - - - - - - - - - - - - - -

  test '245',
  %w( when exec(command) is non-zero,
      it does not raise,
      it returns [stdout,stderr,status],
      it logs [command,stdout,stderr,status] in json format
  ) do
    command = 'printf Bye && false'
    log,_ = with_captured_log {
      stdout,stderr,status = shell.exec(command)
      assert_equal 'Bye', stdout, :stdout
      assert_equal '', stderr, :stderr
      assert_equal 1, status, :status
    }
    assert_log_contains(log, 'command', command)
    assert_log_contains(log, 'stdout', 'Bye')
    assert_log_contains(log, 'stderr', '')
    assert_log_contains(log, 'status', 1)
  end

  # - - - - - - - - - - - - - - - - -
  # shell.assert(command)
  # - - - - - - - - - - - - - - - - -

  test '247',
  %w( when assert(command) has status of zero,
      it returns stdout,
      it logs nothing
  ) do
    log,_ = with_captured_log {
      stdout = shell.assert('printf Hello')
      assert_equal 'Hello', stdout, :stdout
    }
    assert_equal '', log, :log
  end

  # - - - - - - - - - - - - - - - - -

  test '248',
  %w( when assert(command) has a status of non-zero,
      it raises a ShellAssertError holding [command,stdout,stderr,status],
      it logs [command,stdout,stderr,status]
  ) do
    command = 'printf Hello && false'
    log,_ = with_captured_log {
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

  test '249', %w(
  when assert(command) raises
  the exception is untouched,
  it logs nothing
  ) do
    log,_ = with_captured_log {
      error = assert_raises(Errno::ENOENT) { shell.assert('xxx Hello') }
      expected = 'No such file or directory - xxx'
      assert_equal expected, error.message, :error_message
    }
    assert_equal '', log, :log
  end

  # - - - - - - - - - - - - - - - - -
  # special test for silencing known CircleCI error message
  # - - - - - - - - - - - - - - - - -

  KNOWN_CIRCLE_CI_WARNING =
    "WARNING: Your kernel does not support swap limit capabilities or the cgroup is not mounted. " +
    "Memory limited without swap."

  test '250',
  %w( known warning message on CircleCI is not logged - helps reveal other warnings ) do
    bash_stub =
      Class.new do
        def initialize; @fired_count = 0; end
        def fired?(n); @fired_count === n; end
        def run(command)
          @fired_count += 1
          ['',KNOWN_CIRCLE_CI_WARNING,0]
        end
      end.new
    log_spy =
      Class.new do
        def initialize; @fired_count = 0; end
        def fired?(n); @fired_count === n; end
        def <<(_s); @fired_count += 1; end
      end.new
    @externals = Externals.new({ 'bash' => bash_stub, 'log' => log_spy })
    key = 'CIRCLECI'
    on_circle_ci = ENV.include?(key)
    begin
      ENV[key] = 'true' unless on_circle_ci
      shell.exec('anything')
    ensure
      ENV.delete(key) unless on_circle_ci
    end
    assert bash_stub.fired?(1), 'bash_stub.fired?(1) is false'
    assert log_spy.fired?(0), 'log_spy.fired?(0) is false'
  end

  private

  def assert_log_contains(log, key, value)
    refute_nil log
    json = JSON.parse(log)
    diagnostic = "log does not contain key:#{key}\n#{log}"
    assert json.has_key?(key), diagnostic
    assert_equal value, json[key], log
  end

  def assert_error_contains(error, key, value)
    refute_nil error
    refute_nil error.message
    json = JSON.parse(error.message)
    diagnostic = "error.message does not contain key:#{key}\n#{error.message}"
    assert json.has_key?(key), diagnostic
    assert_equal value, json[key], error.message
  end

end
