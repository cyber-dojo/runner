require_relative 'sheller_error'

class Sheller

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
    unless status == success
      raise ShellerError.new(stderr, {
        command:command,
        stdout:stdout,
        stderr:stderr,
        status:status
      })
    end
    stdout
  end

  def success
    0
  end

  private # = = = = = = = = = = = = = = = = =

  def bash_run(command)
    stdout,stderr,status = bash.run(command)
    [stdout, stderr, status]
  rescue Exception => error
    raise ShellerError.new(error.message, {
      command:command,
      message:error.message
    })
  end

  def bash
    @external.bash
  end

end

