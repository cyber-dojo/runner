require_relative 'test_base'
require_relative 'log_spy'

class LogSpyTest < TestBase

  def self.hex_prefix
    'CD476'
  end

  # - - - - - - - - - - - - - - - -

  test '20C',
  'logged message is spied' do
    log = LogSpy.new
    assert_equal [], log.spied
    log << 'hello'
    assert_equal ['hello'], log.spied
    log << 'world'
    assert_equal ['hello','world'], log.spied
  end

end
