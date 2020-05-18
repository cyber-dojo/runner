# frozen_string_literal: true
require_relative 'test_base'
require_src 'result_logger'

class ResultLoggerTest < TestBase

  def self.id58_prefix
    'qR9'
  end

  # - - - - - - - - - - - - - - - - -

  test 'dF7', %w( write(s) is a no-op when s is empty ) do
    result = { 'log' => 'xxx' }
    logger = ResultLogger.new(result)
    logger.write('')
    assert_equal 'xxx', result['log']
  end

  # - - - - - - - - - - - - - - - - -

  test 'dF8', %w( write(s) logs s and a trailing newline if s does not end in a newline ) do
    result = { 'log' => "xxx\n" }
    logger = ResultLogger.new(result)
    logger.write('hello')
    assert_equal "xxx\nhello\n", result['log']
  end

  # - - - - - - - - - - - - - - - - -

  test 'dF9', %w( write(s) logs s only if s already ends in a newline ) do
    result = { 'log' => "xxx\n" }
    logger = ResultLogger.new(result)
    logger.write("hello\n")
    assert_equal "xxx\nhello\n", result['log']
  end

end
