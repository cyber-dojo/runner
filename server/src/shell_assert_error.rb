require 'json'

class ShellAssertError < StandardError

  def initialize(command, stdout, stderr, status)
    super(JSON.pretty_generate({
      'command' => command,
      'stdout'  => stdout,
      'stderr'  => stderr,
      'status'  => status
    }))
  end

=begin
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
=end

end
