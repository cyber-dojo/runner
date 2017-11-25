require_relative 'disk_writer'
require_relative 'shell_basher'
require_relative 'logger_stdout'

module Externals # mix-in

  def shell
    @shell ||= ShellBasher.new(self)
  end

  def disk
    @disk ||= DiskWriter.new(self)
  end

  def log
    @log ||= LoggerStdout.new(self)
  end

end
