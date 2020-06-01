# frozen_string_literal: true

class StderrWriter

  def write(message)
    return if message.empty?
    message += "\n" if message[-1] != "\n"
    $stderr.write(message)
  end

end
