require 'open3'

class BashStubRagFileCatter

  def initialize(content)
    @content = content
    @fired_count = 0
  end

  def fired_once?
    @fired_count === 1
  end

  def run(command)
    if command.end_with?("cat /usr/local/bin/red_amber_green.rb'")
      @fired_count += 1
      return stdout=@content,stderr='',status=0
    else
      stdout,stderr,r = Open3.capture3(command)
      [ stdout, stderr, r.exitstatus ]
    end
  end

end
