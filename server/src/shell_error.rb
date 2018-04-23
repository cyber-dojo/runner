
class ShellError < StandardError

  def initialize(command, error = nil)
    if error
      set_backtrace(error.backtrace)
      @message = {
        'command' => command,
        'error' => error.message,
      }.to_json
    else
      @message = command
    end
  end

  attr_reader :message

end
