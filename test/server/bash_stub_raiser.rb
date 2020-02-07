
class BashStubRaiser

  def initialize(message)
    @message = message
    @fired_count = 0
  end

  def fired_once?
    @fired_count === 1
  end

  def run(command)
    @fired_count += 1
    raise ArgumentError.new(@message)
  end

end
