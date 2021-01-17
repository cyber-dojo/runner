# frozen_string_literal: true
require_relative '../test_base'
require_code 'files_delta'
require_code 'utf8_clean'

class FilesDeltaTest < TestBase

  def self.id58_prefix
    '5C2'
  end

  include FilesDelta

  # - - - - - - - - - - - - - - - - -

  test 'E76', %w( unchanged content ) do
    was_files = { 'wibble.txt' => 'hello' }
    now_files = { 'wibble.txt' => intact('hello') }
    created,deleted,changed = files_delta(was_files, now_files)
    assert_equal({}, created)
    assert_equal({}, deleted)
    assert_equal({}, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E77', %w( changed content ) do
    was_files = { 'wibble.txt' => 'hello' }
    now_files = { 'wibble.txt' => intact('hello, world') }
    created,deleted,changed = files_delta(was_files, now_files)
    assert_equal({}, created)
    assert_equal({}, deleted)
    assert_equal({'wibble.txt' => intact('hello, world')}, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test 'q77', %w( changed content caused by string cleaning ) do
    dirty = (100..1000).to_a.pack('c*').force_encoding('utf-8')
    clean = Utf8.clean(dirty)
    was_files = { 'wibble.txt' => dirty }
    now_files = { 'wibble.txt' => clean }
    created,deleted,changed = files_delta(was_files, now_files)
    assert_equal({}, created)
    assert_equal({}, deleted)
    assert_equal({'wibble.txt' => clean}, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E78', %w( deleted content ) do
    filename = 'wibble.txt'
    content = 'hello'
    was_files = { filename => content }
    now_files = {}
    created,deleted,changed = files_delta(was_files, now_files)
    expected_deleted = {
      filename => {
        'content' => content
      }
    }
    assert_equal({}, created)
    assert_equal(expected_deleted, deleted)
    assert_equal({}, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E79', %w( new content ) do
    was_files = {}
    now_files = { 'wibble.txt' => intact('hello') }
    created,deleted,changed = files_delta(was_files, now_files)
    assert_equal({'wibble.txt' => intact('hello')}, created)
    assert_equal({}, deleted)
    assert_equal({}, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test 'E80', %w( new empty content ) do
    was_files = {}
    now_files = { 'empty.file' => intact('') }
    created,deleted,changed = files_delta(was_files, now_files)
    assert_equal({'empty.file' => intact('')}, created)
    assert_equal({}, deleted)
    assert_equal({}, changed)
  end

end
