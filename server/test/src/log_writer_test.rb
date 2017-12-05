require_relative 'test_base'

class LogWriterTest < TestBase

  def self.hex_prefix
    '1B67B'
  end

  test '962',
  'write() appends to messages' do
    log = LogWriter.new
    log.write("Hello world")
    assert_equal ['Hello world'], log.messages
    log.write({ 'x' => 42 })
    assert_equal ['Hello world', { 'x' => 42 }], log.messages
  end

end
