
class BashStub

  def initialize
    @stubs = []
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def teardown
    unless uncaught_exception?
      unless @stubs === []
        pretty = JSON.pretty_generate(@stubs)
        raise "#{ENV['ID58']}: uncalled stubs(#{pretty})"
      end
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def stub_exec(command, stdout, stderr, status)
    @stubs << {
      command:command,
       stdout:stdout,
       stderr:stderr,
       status:status
    }
  end

  def exec(command)
    stub = @stubs.shift
    if stub.nil?
      raise [
        self.class.name,
        "exec(command) - no stub",
        "actual-command: #{command}",
      ].join("\n") + "\n"
    end
    unless command === stub[:command]
      raise [
        self.class.name,
        "exec(command) - does not match stub",
        " actual-command:#{command}:",
        "stubbed-command:#{stub[:command]}:"
      ].join("\n") + "\n"
    end
    [stub[:stdout], stub[:stderr], stub[:status]]
  end

  def uncaught_exception?
    $!
  end

end
