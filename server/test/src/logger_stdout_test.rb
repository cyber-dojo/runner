require_relative 'test_base'

class LoggerStdoutTest < TestBase

  def self.hex_prefix; '1B6'; end

  test '962',
  '<< writes to stdout with added trailing newline' do
    written = with_captured_stdout { log << "Hello world" }
    assert_equal quoted('Hello world')+"\n", written
  end

  private

  def with_captured_stdout
    begin
      old_stdout = $stdout
      $stdout = StringIO.new('','w')
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  end

  def quoted(s)
    '"' + s + '"'
  end

end
