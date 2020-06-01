require_relative 'test_base'
require_relative 'stream_writer_spy'

class StreamWriterSpyTest < TestBase

  def self.id58_prefix
    '60e'
  end

  # - - - - - - - - - - - - - - - - -

  test 'dF7', %w( write(s) is a no-op when s is empty ) do
    assert_equal '', write('')
  end

  # - - - - - - - - - - - - - - - - -

  test 'dF8', %w( write(s) logs s and a trailing newline when s does not end in a newline ) do
    assert_equal "hello\n", write('hello')
  end

  # - - - - - - - - - - - - - - - - -

  test 'dF9', %w( write(s) logs s as it is when s ends in a newline ) do
    assert_equal "world\n", write("world\n")
  end

  private

  def write(s)
    spy = StreamWriterSpy.new
    spy.write(s)
    spy.spied.join
  end

end
