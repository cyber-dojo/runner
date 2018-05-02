
class BashStubStatus

  def initialize(status)
    @status = status
    @fired = false
  end

  def fired?
    @fired
  end

  def run(_command)
    @fired = true
    [ 'stubbed_stdout', 'stubbed_stderr', @status ]
  end

end