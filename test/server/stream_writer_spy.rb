# frozen_string_literal: true

class StreamWriterSpy

  def initialize
    @spied = []
  end

  attr_reader :spied

  def write(message)
    return if message.empty?
    message += "\n" if message[-1] != "\n"
    @spied << message
  end

end
