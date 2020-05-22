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
      logger.write("command:#{command}:")
      logger.write("status:#{status}:")
      logger.write("stderr:#{stderr}:")
    end
    [ stdout, stderr, r.exitstatus ]
  end

  def assert(command)
    stdout,stderr,r = Open3.capture3(command)
    [ stdout, stderr, r.exitstatus ]
  end

  private

  def logger
    @externals.logger
  end

end
