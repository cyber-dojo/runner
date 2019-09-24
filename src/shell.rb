# frozen_string_literal: true

require_relative 'shell_assert_error'

class Shell

  def initialize(externals)
    @externals = externals
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def exec(command)
    bash_run(command)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def assert(command)
    stdout,stderr,status = bash_run(command)
    unless success?(status)
      args = [command,stdout,stderr,status]
      raise ShellAssertError.new(*args)
    end
    stdout
  end

  private

  SUCCESS = 0

  def success?(status)
    status === SUCCESS
  end

  def bash_run(command)
    stdout,stderr,status = bash.run(command)
    unless success?(status) && ignore?(stderr)
      args = [command,stdout,stderr,status]
      log << ShellAssertError.new(*args).message
    end
    [stdout, stderr, status]
  end

  # - - - - - - - - - - - - - - - - - - -

  def ignore?(stderr)
    stderr.empty? || known_circle_ci_warning?(stderr)
  end

  KNOWN_CIRCLE_CI_WARNING =
    "WARNING: Your kernel does not support swap limit capabilities or the cgroup is not mounted. " +
    "Memory limited without swap."

  def known_circle_ci_warning?(stderr)
    on_circle_ci? && stderr.start_with?(KNOWN_CIRCLE_CI_WARNING)
  end

  def on_circle_ci?
    ENV.include?('CIRCLECI')
  end

  # - - - - - - - - - - - - - - - - - - -

  def bash
    @externals.bash
  end

  def log
    @externals.log
  end

end
