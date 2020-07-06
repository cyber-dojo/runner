# frozen_string_literal: true

class ExternalLogger

  def initialize
    @stream = $stdout
  end

  def log(message)
    unless message.empty?
      message += "\n" if message[-1] != "\n"
      @stream.write(message)
    end
  end

end
