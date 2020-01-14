require_relative 'test_base'
require 'stringio'

class LogTest < TestBase

  def self.hex_prefix
    'CE4'
  end

  def log
    externals.log
  end

  # - - - - - - - - - - - - - - - -

  test '20C',
  'logging a string message send it directly to stdout' do
    stdout = captured_stdout {
      log << 'Hello'
    }
    assert_equal 'Hello', stdout
  end

  # - - - - - - - - - - - - - - - -

  def captured_stdout
    begin
      old_stdout = $stdout
      $stdout = StringIO.new('', 'w')
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  end

end
