require_relative 'test_base'
require_relative 'logger_spy'

class LoggerSpyTest < TestBase

  def self.hex_prefix
    'CD4F1'
  end

  test '20C',
  'logged message is spied' do
    log = LoggerSpy.new(nil)
    assert_equal [], log.spied
    log.write('hello')
    assert_equal ['hello'], log.spied
    log.write('world')
    assert_equal ['hello','world'], log.spied
  end

end
