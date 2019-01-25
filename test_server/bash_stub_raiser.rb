
class BashStubRaiser

  def initialize(message)
    @message = message
    @fired = false
  end

  def fired?
    @fired
  end

  def run(command)
    @fired = true
    raise ArgumentError.new(@message)
  end

end
