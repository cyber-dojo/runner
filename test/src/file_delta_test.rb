require_relative '../../src/file_delta'
require_relative 'test_base'

class FileDeltaTest < TestBase

  def self.hex_prefix
    '5C2'
  end

  include FileDelta

  # - - - - - - - - - - - - - - - - -

  test 'E76', %w( unchanged content) do
    was_files = { 'wibble.txt' => file('hello') }
    now_files = { 'wibble.txt' => file('hello') }
    file_delta(was_files, now_files)
    assert_equal({}, @created_files)
    assert_equal({}, @deleted_files)
    assert_equal({}, @changed_files)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E77', %w( changed content ) do
    was_files = { 'wibble.txt' => file('hello') }
    now_files = { 'wibble.txt' => file('hello, world') }
    file_delta(was_files, now_files)
    assert_equal({}, @created_files)
    assert_equal({}, @deleted_files)
    assert_equal({'wibble.txt' => file('hello, world')}, @changed_files)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E78', %w( deleted content ) do
    was_files = { 'wibble.txt' => file('hello') }
    now_files = {}
    file_delta(was_files, now_files)
    assert_equal({}, @created_files)
    assert_equal({'wibble.txt' => file('hello')}, @deleted_files)
    assert_equal({}, @changed_files)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E79', %w( new content ) do
    was_files = {}
    now_files = { 'wibble.txt' => file('hello') }
    file_delta(was_files, now_files)
    assert_equal({'wibble.txt' => file('hello')}, @created_files)
    assert_equal({}, @deleted_files)
    assert_equal({}, @changed_files)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E80', %w( new empty content ) do
    was_files = {}
    now_files = { 'empty.file' => file('') }
    file_delta(was_files, now_files)
    assert_equal({'empty.file' => file('')}, @created_files)
    assert_equal({}, @deleted_files)
    assert_equal({}, @changed_files)
  end

end
