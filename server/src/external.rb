require_relative 'bash'
require_relative 'disk'
require_relative 'shell'
require_relative 'log'
require_relative 'writer'

class External

  def initialize
    @bash = Bash.new
    @disk = Disk.new
    @log = Log.new
    @shell = Shell.new(self)
    @writer = Writer.new
  end

  attr_reader :bash, :disk, :log, :shell, :writer

  def bash=(doppel)
    @bash = doppel
  end

  def writer=(doppel)
    @writer = doppel
  end

end
