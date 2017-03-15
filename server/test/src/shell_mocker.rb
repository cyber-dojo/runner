
class ShellMocker

  def initialize(_parent)
    hex_test_id = ENV['CYBER_DOJO_HEX_TEST_ID']
    @filename = Dir.tmpdir + '/cyber_dojo_mock_sheller_' + hex_test_id + '.json'
    write([]) unless File.file?(filename)
  end

  # - - - - - - - - - - - - - - - - - - - - - - -

  def teardown
    if !uncaught_exception?
      mocks = read
      pretty = JSON.pretty_generate(mocks)
      fail "#{filename}: uncalled mocks(#{pretty})" unless mocks == []
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

  def assert_exec(command)
    stdout,stderr,status = exec(command)
    if status != success
      fail ArgumentError.new("command:#{command}")
    end
    [stdout,stderr]
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
    if command != mock['command']
      raise [
        self.class.name,
        "exec(command) - does not match mock",
        "actual-command: #{command}",
        "mocked-command: #{mock['command']}}"
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
