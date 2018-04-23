
class Log

  def initialize
    @messages = []
  end

  attr_reader :messages

  def <<(message)
    @messages << message
  end

end
