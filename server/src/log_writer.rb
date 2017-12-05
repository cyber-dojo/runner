
class LogWriter

  def initialize
    @messages = []
  end

  attr_reader :messages

  def write(message)
    @messages << message
  end

end
