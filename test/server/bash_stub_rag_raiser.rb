require 'open3'

class BashStubRagRaiser

  def initialize(message)
    @message = message
    @fired_count = 0
  end

  def fired_once?
    @fired_count === 1
  end

  def exec(command)
    if command.end_with?("cat /usr/local/bin/red_amber_green.rb'")
      @fired_count += 1
      raise ArgumentError.new(@message)
    else
      stdout,stderr,r = Open3.capture3(command)
      [ stdout, stderr, r.exitstatus ]
    end
  end

end
