require_relative 'test_base'
require_source 'stdout_writer'

class StdoutWriterTest < TestBase

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
    writer = StdoutWriter.new(nil)
    captured_stdout { writer.write(s) }
  end

  def captured_stdout
    begin
      old_stdout = $stdout
      $stdout = StringIO.new('', 'w')
      yield
      captured = $stdout.string
    ensure
      $stdout = old_stdout
    end
    captured
  end

end
