# frozen_string_literal: true
require_relative 'test_base'
require_src 'result_logger'

class ResultLoggerTest < TestBase

  def self.id58_prefix
    'qR9'
  end

  def id58_setup
    @result = {}
    @logger = ResultLogger.new(@result)
  end

  attr_reader :logger

  def log
    @result['log']
  end

  # - - - - - - - - - - - - - - - - -

  test 'dF6', %w( log is initially empty ) do
    assert_equal '', log
  end

  # - - - - - - - - - - - - - - - - -

  test 'dF7', %w( write(s) is a no-op when s is empty ) do
    logger.write('')
    assert_equal '', log
  end

  # - - - - - - - - - - - - - - - - -

  test 'dF8', %w( write(s) logs s and a trailing newline if s does not end in a newline ) do
    logger.write('hello')
    assert_equal "hello\n", log
    logger.write('world')
    assert_equal "hello\nworld\n", log
  end

  # - - - - - - - - - - - - - - - - -

  test 'dF9', %w( write(s) logs s only if s already ends in a newline ) do
    logger.write("hello\n")
    assert_equal "hello\n", log
    logger.write("world\n")
    assert_equal "hello\nworld\n", log
  end

end