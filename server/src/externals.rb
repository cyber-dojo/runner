require_relative 'disk_writer'
require_relative 'sheller'
require_relative 'log_writer'

module Externals # mix-in

  def shell
    @shell ||= Sheller.new(self)
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
