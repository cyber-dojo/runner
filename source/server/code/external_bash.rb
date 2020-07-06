# frozen_string_literal: true
require 'open3'

class ExternalBash

  def initialize(context)
    @context = context
  end

  def execute(command)
    stdout,stderr,r = Open3.capture3(command)
    status = r.exitstatus
    unless status === 0
      logger.write("command:#{command}:")
      logger.write("stdout:#{stdout}:")
      logger.write("stderr:#{stderr}:")
      logger.write("status:#{status}:")
    end
    [ stdout, stderr, status ]
  end

  private

  def logger
    @context.logger
  end

end
