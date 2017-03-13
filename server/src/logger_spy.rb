
class LoggerSpy

  def initialize(_parent)
    @spied = []
  end

  attr_reader :spied

  def <<(message)
    spied << message
  end

end
