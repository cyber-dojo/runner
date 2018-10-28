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

end
