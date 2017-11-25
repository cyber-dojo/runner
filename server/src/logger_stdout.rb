
class LoggerStdout

  def initialize(_parent)
    @messages = []
  end

  attr_reader :messages

  def <<(message)
    @messages << message
  end

end
