require 'open3'

class BashStubTarPipeOut

  def initialize(content)
    @content = content
    @fired_count = 0
  end

  def fired_once?
    @fired_count === 1
  end

  def run(command)
    if command.include?('source /tmp/echo_truncated_textfilenames.sh')
      @fired_count += 1
      return stdout=@content,stderr='',status=1
    else
      stdout,stderr,r = Open3.capture3(command)
      [ stdout, stderr, r.exitstatus ]
    end
  end

end
