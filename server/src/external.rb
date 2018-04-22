require_relative 'bash'
require_relative 'disk'
require_relative 'shell'
require_relative 'log_stdout'

class External

  def initialize
    @bash = Bash.new
    @disk = Disk.new
    @log = LogStdout.new
    @shell = Shell.new(self)
  end

  attr_reader :bash, :disk, :log, :shell

  def bash=(doppel)
    @bash = doppel
  end

  def log=(doppel)
    @log = doppel
  end

end
