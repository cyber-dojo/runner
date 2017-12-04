require_relative 'runner_error'

class Sheller

  def initialize(external)
    @external = external
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def assert(command)
    stdout,stderr,status = bash_run('assert', command)
    unless status == success
      raise RunnerError.new(info('assert', command, stdout, stderr, status))
    end
    stdout
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def exec(command)
    stdout,stderr,status = bash_run('exec', command)
    unless status == success
      log.write(info('exec', command, stdout, stderr, status))
    end
    [stdout, stderr, status]
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def success
    0
  end

  private # = = = = = = = = = = = = = = = = =

  def bash_run(method_name, command)
    stdout,stderr,status = bash.run(command)
    [ stdout, stderr, status ]
  rescue StandardError => error
    raise RunnerError.new({
      'command':shell_call(method_name, command),
      'message':error.message
    })
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def info(method, command, stdout, stderr, status)
    { 'command':shell_call(method, command),
      'stdout':stdout,
      'stderr':stderr,
      'status':status
    }
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def shell_call(method, command)
    "shell.#{method}(\"#{command}\")"
  end

  # - - - - - - - - - - - - - - - - - - - - -

  def bash
    @external.bash
  end

  def log
    @external.log
  end

end

