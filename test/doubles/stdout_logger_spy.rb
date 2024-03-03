class StdoutLoggerSpy
  def initialize
    @logged = ''
  end

  attr_reader :logged

  def log(message)
    return if message.empty?

    message += "\n" if message[-1] != "\n"
    @logged += message
  end
end
