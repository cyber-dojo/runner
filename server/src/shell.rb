require_relative 'shell_error'

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
    stdout,_stderr,status = bash_run(command)
    unless status == success
      raise ShellError.new(command)
    end
    stdout
  end

  def success
    0
  end

  private # = = = = = = = = = = = = = = = = =

  def bash_run(command)
    stdout,stderr,status = bash.run(command)
    unless status == success
      log << {
        'command' => command,
        'stdout'  => stdout,
        'stderr'  => stderr,
        'status'  => status
      }.to_json
    end
    [stdout, stderr, status]
  rescue => error
    raise ShellError.new(command, error)
  end

  def bash
    @external.bash
  end

  def log
    @external.log
  end

end

