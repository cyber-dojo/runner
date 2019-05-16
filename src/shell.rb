require_relative 'shell_assert_error'

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
    unless success?(status) && stderr.empty?
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
