
class WriterSpy

  def initialize
    @spied = []
  end

  def write(info)
    @spied << info
  end

  attr_reader :spied

end
