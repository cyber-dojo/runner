
class BashStub

  def initialize
    hex_test_id = ENV['CYBER_DOJO_HEX_TEST_ID']
    @filename = Dir.tmpdir + '/cyber_dojo_bash_stub_' + hex_test_id + '.json'
    unless File.file?(filename)
      write([])
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def teardown
    unless uncaught_exception?
      stubs = read
      pretty = JSON.pretty_generate(stubs)
      unless stubs === []
        raise "#{filename}: uncalled stubs(#{pretty})"
      end
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def stub_run(command, stdout, stderr, status)
    stubs = read
    stub = {
      command:command,
       stdout:stdout,
       stderr:stderr,
       status:status
    }
    write(stubs << stub)
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def run(command)
    stubs = read
    stub = stubs.shift
    write(stubs)
    if stub.nil?
      raise [
        self.class.name,
        "run(command) - no stub",
        "actual-command: #{command}",
      ].join("\n") + "\n"
    end
    unless command === stub['command']
      raise [
        self.class.name,
        "run(command) - does not match stub",
        "actual-command: #{command}",
        "stubbed-command: #{stub['command']}"
      ].join("\n") + "\n"
    end
    [stub['stdout'], stub['stderr'], stub['status']]
  end

  private # = = = = = = = = = = = = = = = = = =

  def read
    JSON.parse(IO.read(filename))
  end

  def write(stubs)
    IO.write(filename, JSON.unparse(stubs))
  end

  def filename
    @filename
  end

  def uncaught_exception?
    $!
  end

end
