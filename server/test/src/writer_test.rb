require_relative 'test_base'
require_relative '../../src/writer'

class WriterTest < TestBase

  def self.hex_prefix
    '1B63E'
  end

  test '962',
  '<< writes to stdout with added trailing newline' do
    writer = Writer.new
    written = with_captured_stdout {
      writer.write('Hello world')
    }
    assert_equal quoted('Hello world')+"\n", written
  end

  private

  def quoted(s)
    '"' + s + '"'
  end

end
