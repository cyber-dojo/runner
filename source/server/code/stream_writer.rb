# frozen_string_literal: true

class StreamWriter

  def initialize(stream)
    @stream = stream
  end

  def write(message)
    unless message.empty?
      message += "\n" if message[-1] != "\n"
      @stream.write(message)
    end
  end

end
