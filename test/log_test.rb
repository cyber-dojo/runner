require_relative 'test_base'
require_relative '../src/log'

class LogTest < TestBase

  def self.hex_prefix
    'CD4'
  end

  # - - - - - - - - - - - - - - - -

  test '20C',
  'logging a string message send it directly to stdout' do
    stdout = captured_stdout {
      Log.new << 'Hello'
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
