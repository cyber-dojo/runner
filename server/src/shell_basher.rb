require 'open3'

class ShellBasher

  def initialize(parent)
    @log = parent.log
  end

  def assert(command)
    stdout,_stderr,status = exec(command)
    unless status == success
      fail ArgumentError.new("command:#{command}")
    end
    stdout
  end

  def exec(command)
    begin
      stdout,stderr,ps = Open3.capture3(command)
      status = ps.exitstatus
      unless ps.success?
        log << line
        log << "COMMAND:#{command}"
        log << "STATUS:#{status}"
        log << "STDOUT:#{stdout}"
        log << "STDERR:#{stderr}"
      end
      [stdout, stderr, status]
    rescue StandardError => error
      log << line
      log << "COMMAND:#{command}"
      log << "RAISED-CLASS:#{error.class.name}"
      log << "RAISED-TO_S:#{error.to_s}"
      raise error
    end
  end

  def success
    0
  end

  private

  attr_reader :log

  def line
    '-' * 40
  end

end
