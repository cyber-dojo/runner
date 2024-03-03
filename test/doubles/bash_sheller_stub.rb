# frozen_string_literal: true
require 'json'

class BashShellerStub
  def initialize
    @stubs = []
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def teardown
    return if uncaught_exception?
    return if @stubs == []

    pretty = JSON.pretty_generate(@stubs)
    raise "#{ENV.fetch('ID58', nil)}: uncalled stubs(#{pretty})"
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def capture(command)
    if block_given?
      stub = yield
      @stubs << {
        command: command,
        stdout: stub[0],
        stderr: stub[1],
        status: stub[2]
      }
    else
      matching_stub(command)
    end
  end

  private

  def matching_stub(command)
    stub = @stubs.shift
    if stub.nil?
      raise [
        self.class.name,
        'capture(command) - no stub',
        "actual-command: #{command}"
      ].join("\n") + "\n"
    end
    unless command == stub[:command]
      raise [
        self.class.name,
        'capture(command) - does not match stub',
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
