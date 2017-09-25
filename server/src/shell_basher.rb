require_relative 'nearest_ancestors'
require 'open3'

class ShellBasher

  def initialize(parent)
    @parent = parent
  end

  attr_reader :parent

  def assert_exec(command)
    stdout,stderr,status = exec(command)
    if status != success
      fail ArgumentError.new("command:#{command}")
    end
    [stdout,stderr]
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

  include NearestAncestors

  def log
    @log ||= nearest_ancestors(:log)
  end

  def line
    '-' * 40
  end

end
