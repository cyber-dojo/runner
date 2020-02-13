# frozen_string_literal: true
class Log

  def <<(message)
    $stdout.print(message)
  end

end
