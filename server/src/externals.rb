require_relative 'disk_writer'
require_relative 'shell_basher'
require_relative 'log_writer'

module Externals # mix-in

  def shell
    @shell ||= ShellBasher.new(self)
  end
  def shell=(doppel)
    @shell = doppel
  end

  def disk
    @disk ||= DiskWriter.new(self)
  end

  def log
    @log ||= LogWriter.new(self)
  end

end
