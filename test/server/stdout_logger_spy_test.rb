require_relative '../test_base'

class StdoutLoggerSpyTest < TestBase

  test '60edF7', %w(log(s) is a no-op when s is empty) do
    assert_equal '', log('')
  end

  # - - - - - - - - - - - - - - - - -

  test '60edF8', %w(log(s) logs s and a trailing newline when s does not end in a newline) do
    assert_equal "hello\n", log('hello')
  end

  # - - - - - - - - - - - - - - - - -

  test '60edF9', %w(log(s) logs s as it is when s ends in a newline) do
    assert_equal "world\n", log("world\n")
  end

  private

  def log(message)
    spy = StdoutLoggerSpy.new
    spy.log(message)
    spy.logged
  end
end
