
class ShellCatRagFileStub

    def initialize(adaptee, content)
      @adaptee = adaptee
      @content = content
      @fired = false
    end

    def fired?
      @fired
    end

    def assert(command)
      if command.end_with? "cat /usr/local/bin/red_amber_green.rb'"
        @fired = true
        @content
      else
        @adaptee.assert(command)
      end
    end

end
