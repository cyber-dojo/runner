require_relative 'bash'
require_relative 'shell'
require_relative 'log'

class External

  def initialize(options = {})
    @bash = options['bash'] || Bash.new
    @log = Log.new
    @shell = Shell.new(self)
  end

  attr_reader :bash, :log, :shell

end
