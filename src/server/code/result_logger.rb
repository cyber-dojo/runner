# frozen_string_literal: true

class ResultLogger

  def initialize(result)
    @result = result
    @result['log'] = ''
  end

  def write(message)
    return if message.empty?
    message += "\n" if message[-1] != "\n"
    @result['log'] += message
  end

end
