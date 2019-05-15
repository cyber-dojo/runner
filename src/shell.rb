require_relative 'shell_assert_error'
require 'json'

class Shell

  def initialize(external)
    @external = external
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def exec(command)
    bash_run(command)
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def assert(command)
    stdout,stderr,status = bash_run(command)
    unless status === success
      args = [command,stdout,stderr,status]
      raise ShellAssertError.new(*args)
    end
    stdout
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def success
    0
  end

  private

  def bash_run(command)
    stdout,stderr,status = bash.run(command)
    unless status === success
      args = [command,stdout,stderr,status]
      log << ShellAssertError.new(*args).message
    end
    [stdout, stderr, status]
  end

  def bash
    @external.bash
  end

  def log
    @external.log
  end

end
