require_relative 'bash'
require_relative 'disk'
require_relative 'shell'

class External

  def initialize
    @bash = Bash.new
    @disk = Disk.new
    @shell = Shell.new(self)
  end

  attr_reader :bash, :disk, :shell

  def bash=(doppel)
    @bash = doppel
  end

end
