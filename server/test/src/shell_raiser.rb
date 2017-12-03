
class ShellRaiser

    def initialize(adaptee)
      @adaptee = adaptee
      @fired = false
    end

    def fired?
      @fired
    end

    def assert(command)
      if command.end_with? "cat /usr/local/bin/red_amber_green.rb'"
        @fired = true
        raise ArgumentError.new
      else
        @adaptee.assert(command)
      end
    end

end