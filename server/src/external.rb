require_relative 'bash'
require_relative 'disk'
require_relative 'ledger'

class External

  def initialize
    @bash   = Bash.new
    @disk   = Disk.new
    @ledger = Ledger.new
  end

  attr_reader :bash, :disk, :ledger

  def bash=(doppel)
    @bash = doppel
  end

end
