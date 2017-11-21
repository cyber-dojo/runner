require_relative 'test_base'
require_relative 'logger_spy'

class LoggerSpyTest < TestBase

  def self.hex_prefix
    'CD4'
  end

  test '20C',
  'logged message is spied' do
    logger = LoggerSpy.new(nil)
    assert_equal [], logger.spied
    logger << 'hello'
    assert_equal ['hello'], logger.spied
    logger << 'world'
    assert_equal ['hello','world'], logger.spied
  end

end
