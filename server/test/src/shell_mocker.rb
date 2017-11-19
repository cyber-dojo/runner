
class ShellMocker

  def initialize(_parent)
    hex_test_id = ENV['CYBER_DOJO_HEX_TEST_ID']
    @filename = Dir.tmpdir + '/cyber_dojo_mock_sheller_' + hex_test_id + '.json'
    unless File.file?(filename)
      write([])
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def teardown
    unless uncaught_exception?
      mocks = read
      pretty = JSON.pretty_generate(mocks)
      unless mocks == []
        raise "#{filename}: uncalled mocks(#{pretty})"
      end
    end
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def mock_exec(command, stdout, stderr, status)
    mocks = read
    mock = { command:command,
              stdout:stdout,
              stderr:stderr,
              status:status
    }
    write(mocks << mock)
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def assert(command)
    stdout,_stderr,status = exec(command)
    unless status == success
      raise ArgumentError.new("command:#{command}")
    end
    stdout
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def exec(command, _ = nil)
    mocks = read
    mock = mocks.shift
    write(mocks)
    if mock.nil?
      raise [
        self.class.name,
        "exec(command) - no mock",
        "actual-command: #{command}",
      ].join("\n") + "\n"
    end
    unless command == mock['command']
      raise [
        self.class.name,
        "exec(command) - does not match mock",
        "actual-command: #{command}",
        "mocked-command: #{mock['command']}"
      ].join("\n") + "\n"
    end
    [mock['stdout'], mock['stderr'], mock['status']]
  end

  def success
    0
  end

  private

  def read
    JSON.parse(IO.read(filename))
  end

  def write(mocks)
    IO.write(filename, JSON.unparse(mocks))
  end

  def filename
    @filename
  end

  def uncaught_exception?
    $!
  end

end
