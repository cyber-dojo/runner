require_relative 'string_cleaner'
require 'json'

class ShellAssertError < StandardError

  include StringCleaner

  def initialize(command, stdout, stderr, status)
    super(JSON.pretty_generate({
      'command' => cleaned(command),
      'stdout'  => cleaned(stdout),
      'stderr'  => cleaned(stderr),
      'status'  => status
    }))
  end

end
