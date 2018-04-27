require 'open3'

class BashStubTarPipeOut

    def initialize(content)
      @content = content
      @fired = false
    end

    def fired?
      @fired
    end

    def run(command)
      if command.include?('--env TAR_LIST=')
        @fired = true
        return stdout=@content,stderr='',status=1
      else
        stdout,stderr,r = Open3.capture3(command)
        [ stdout, stderr, r.exitstatus ]
      end
    end

end
