require_relative 'test_base'
require_relative '../../src/json_writer'

class JsonWriterTest < TestBase

  def self.hex_prefix
    '1B63E'
  end

  # - - - - - - - - - - - - - -

  def hex_setup
    @writer = JsonWriter.new
  end

  # - - - - - - - - - - - - - -

  test '962',
  '<< writes to stdout with added trailing newline' do
    written = with_captured_stdout {
      @writer.write('Hello world')
    }
    assert_equal quoted('Hello world')+"\n", written
  end

  # - - - - - - - - - - - - - -

  test '963',
  %w( << writes in pretty format ) do
    written = with_captured_stdout {
      @writer.write({
        'log' => ['a','b','c'],
        'exception' => 'image_name:malformed'
      })
    }
    expected = <<~JSON.strip
    {
      \"log\": [
        \"a\",
        \"b\",
        \"c\"
      ],
      \"exception\": \"image_name:malformed\"
    }
    JSON
    assert_equal expected+"\n", written
  end

  private

  def quoted(s)
    '"' + s + '"'
  end

end
