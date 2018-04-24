require_relative 'bash'
require_relative 'disk'
require_relative 'json_writer'
require_relative 'shell'
require_relative 'log'

class External

  def initialize(options = {})
    @bash = options['bash'] || Bash.new
    @writer = JsonWriter.new
    @disk = Disk.new
    @log = Log.new
    @shell = Shell.new(self)
  end

  attr_reader :bash, :disk, :log, :shell, :writer

end
