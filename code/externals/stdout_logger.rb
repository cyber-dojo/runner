class StdoutLogger
  def initialize
    @stream = $stdout
  end

  def log(message)
    return if message.empty?

    message += "\n" if message[-1] != "\n"
    @stream.write(message)
  end
end
