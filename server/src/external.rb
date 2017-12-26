require_relative 'bash'
require_relative 'disk'

class External

  def initialize
    @bash   = Bash.new
    @disk   = Disk.new
  end

  attr_reader :bash, :disk

  def bash=(doppel)
    @bash = doppel
  end

end
