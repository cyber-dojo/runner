require 'open3'

class BashStubRaiser

  def initialize(message)
    @message = message
    @fired = false
  end

  def fired?
    @fired
  end

  def run(command)
    if command.end_with?("cat /usr/local/bin/red_amber_green.rb'")
      @fired = true
      raise ArgumentError.new(@message)
    else
      stdout,stderr,r = Open3.capture3(command)
      [ stdout, stderr, r.exitstatus ]
    end
  end

end