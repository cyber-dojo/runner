require_relative '../src/file_delta'
require_relative 'test_base'

class FileDeltaTest < TestBase

  def self.hex_prefix
    '5C2'
  end

  include FileDelta

  # - - - - - - - - - - - - - - - - -

  test 'E76', %w( unchanged content) do
    was_files = { 'wibble.txt' => intact('hello') }
    now_files = { 'wibble.txt' => intact('hello') }
    file_delta(was_files, now_files)
    assert_equal({}, @created)
    assert_equal({}, @deleted)
    assert_equal({}, @changed)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E77', %w( changed content ) do
    was_files = { 'wibble.txt' => intact('hello') }
    now_files = { 'wibble.txt' => intact('hello, world') }
    file_delta(was_files, now_files)
    assert_equal({}, @created)
    assert_equal({}, @deleted)
    assert_equal({'wibble.txt' => intact('hello, world')}, @changed)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E78', %w( deleted content ) do
    was_files = { 'wibble.txt' => intact('hello') }
    now_files = {}
    file_delta(was_files, now_files)
    assert_equal({}, @created)
    assert_equal({'wibble.txt' => intact('hello')}, @deleted)
    assert_equal({}, @changed)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E79', %w( new content ) do
    was_files = {}
    now_files = { 'wibble.txt' => intact('hello') }
    file_delta(was_files, now_files)
    assert_equal({'wibble.txt' => intact('hello')}, @created)
    assert_equal({}, @deleted)
    assert_equal({}, @changed)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E80', %w( new empty content ) do
    was_files = {}
    now_files = { 'empty.file' => intact('') }
    file_delta(was_files, now_files)
    assert_equal({'empty.file' => intact('')}, @created)
    assert_equal({}, @deleted)
    assert_equal({}, @changed)
  end

end
