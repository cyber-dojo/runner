require_relative 'bash'
require_relative 'log'
require_relative 'shell'

class External

  def initialize(options = {})
    @bash = options['bash'] || Bash.new
    @log = options['log'] || Log.new
    @shell = Shell.new(self)
  end

  attr_reader :bash, :log, :shell

end
