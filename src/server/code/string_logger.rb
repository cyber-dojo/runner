# frozen_string_literal: true

class StringLogger

  def initialize(_externals)
    @log = ''
  end

  attr_reader :log

  def write(message)
    return if message.empty?
    message += "\n" if message[-1] != "\n"
    @log += message
  end

end
