
class LogSpy

  def initialize
    @spied = []
  end

  attr_reader :spied

  def <<(message)
    spied << message
  end

end
