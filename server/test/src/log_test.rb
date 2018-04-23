require_relative 'test_base'
require_relative '../../src/log'

class LogSpyTest < TestBase

  def self.hex_prefix
    'CD476'
  end

  # - - - - - - - - - - - - - - - -

  test '20C',
  'each logged message accumulates in messages' do
    log = Log.new
    assert_equal [], log.messages
    log << 'hello'
    assert_equal ['hello'], log.messages
    log << 'world'
    assert_equal ['hello','world'], log.messages
  end

end
