
class LogWriter

  def initialize(_parent)
    @messages = []
  end

  attr_reader :messages

  def write(message)
    @messages << message
  end

end
