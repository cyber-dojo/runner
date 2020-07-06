# frozen_string_literal: true
require 'open3'

class ExternalSheller

  def initialize(context)
    @context = context
  end

  def capture(command)
    stdout,stderr,r = Open3.capture3(command)
    status = r.exitstatus
    unless status === 0
      message = [
        "command:#{command}:",
        "stdout:#{stdout}:",
        "stderr:#{stderr}:",
        "status:#{status}:"
      ].join("\n")
      logger.log(message)
    end
    [ stdout, stderr, status ]
  end

  private

  def logger
    @context.logger
  end

end
