require_relative 'bash'
require_relative 'disk'
require_relative 'shell'
require_relative 'log'
require_relative 'writer'

class External

  def initialize(options = {})
    @bash   = options['bash']   || Bash.new
    @disk   = options['disk']   || Disk.new
    @log    = options['log']    || Log.new
    @writer = options['writer'] || Writer.new
    @shell = Shell.new(self)
  end

  attr_reader :bash, :disk, :log, :shell, :writer

  def bash=(doppel)
    @bash = doppel
  end

end
