
class LoggerSpy

  def initialize(_parent)
    @spied = []
  end

  attr_reader :spied

  def write(message)
    spied << message
  end

end
