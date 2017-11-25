require_relative 'test_base'

class LoggerStdoutTest < TestBase

  def self.hex_prefix
    '1B67B'
  end

  test '962',
  '<< appends to messages, does not write to stdout, class needs name change' do
    log = LoggerStdout.new(nil)
    log << "Hello world"
    assert_equal ['Hello world'], log.messages
    log << { 'x' => 42 }
    assert_equal ['Hello world', { 'x' => 42 }], log.messages
  end

end
