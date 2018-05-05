require_relative '../../src/file_delta'
require_relative 'test_base'

class FileDeltaTest < TestBase

  def self.hex_prefix
    '5C2B2'
  end

  include FileDelta

  # - - - - - - - - - - - - - - - - -

  test 'E76', %w( unchanged content) do
    was_files = { 'wibble.txt' => 'hello' }
    now_files = { 'wibble.txt' => 'hello' }
    file_delta(was_files, now_files)
    assert_equal({}, @new_files)
    assert_equal({'wibble.txt' => 'hello'}, @unchanged_files)
    assert_equal({}, @deleted_files)
    assert_equal({}, @changed_files)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E77', %w( changed content ) do
    was_files = { 'wibble.txt' => 'hello' }
    now_files = { 'wibble.txt' => 'hello, world' }
    file_delta(was_files, now_files)
    assert_equal({}, @new_files)
    assert_equal({}, @unchanged_files)
    assert_equal({}, @deleted_files)
    assert_equal({'wibble.txt' => 'hello, world'}, @changed_files)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E78', %w( deleted content ) do
    was_files = { 'wibble.txt' => 'hello' }
    now_files = {}
    file_delta(was_files, now_files)
    assert_equal({}, @new_files)
    assert_equal({}, @unchanged_files)
    assert_equal({'wibble.txt' => 'hello'}, @deleted_files)
    assert_equal({}, @changed_files)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E79', %w( new content ) do
    was_files = {}
    now_files = { 'wibble.txt' => 'hello' }
    file_delta(was_files, now_files)
    assert_equal({'wibble.txt' => 'hello'}, @new_files)
    assert_equal({}, @unchanged_files)
    assert_equal({}, @deleted_files)
    assert_equal({}, @changed_files)
  end

end

