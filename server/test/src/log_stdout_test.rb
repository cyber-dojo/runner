require_relative 'test_base'

class LogStdoutTest < TestBase

  def self.hex_prefix
    '1B63E'
  end

  test '962',
  '<< writes to stdout with added trailing newline' do
    written = with_captured_stdout { external.log << "Hello world" }
    assert_equal 'Hello world'+"\n", written
  end

end
