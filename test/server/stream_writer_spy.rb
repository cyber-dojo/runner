# frozen_string_literal: true

class StreamWriterSpy

  def initialize
    @written = ''
  end

  attr_reader :written

  def write(message)
    unless message.empty?
      message += "\n" if message[-1] != "\n"
      @written += message
    end
  end

end
