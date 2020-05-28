# frozen_string_literal: true
require 'open3'

class ExternalBash

  def initialize(externals)
    @externals = externals
  end

  def exec(command)
    stdout,stderr,r = Open3.capture3(command)
    status = r.exitstatus
    unless status === 0 && stderr.empty?
      log(command, stdout, stderr, status)
    end
    [ stdout, stderr, status ]
  end

  private

  def log(command, stdout, stderr, status)
    logger.write("command:#{command}:")
    logger.write("stdout:#{stdout}:")
    logger.write("stderr:#{stderr}:")
    logger.write("status:#{status}:")
  end

  def logger
    @externals.logger
  end

end
