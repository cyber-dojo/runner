require_relative 'utf8_clean'
require 'json'

class ShellAssertError < StandardError

  def initialize(command, stdout, stderr, status)
    super(JSON.pretty_generate({
      'command' => Utf8::clean(command),
      'stdout'  => Utf8::clean(stdout),
      'stderr'  => Utf8::clean(stderr),
      'status'  => status
    }))
  end

end
