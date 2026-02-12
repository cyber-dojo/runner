require_relative '../test_base'
require_code 'files_delta'
require_code 'utf8_clean'

class FilesDeltaTest < TestBase

  include FilesDelta

  test '5C2E76', %w[unchanged content] do
    was_files = { 'wibble.txt' => 'hello' }
    now_files = { 'wibble.txt' => intact('hello') }
    created, changed = files_delta(was_files, now_files)
    assert_equal({}, created)
    assert_equal({}, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test '5C2E77', %w[changed content] do
    was_files = { 'wibble.txt' => 'hello' }
    now_files = { 'wibble.txt' => intact('hello, world') }
    created, changed = files_delta(was_files, now_files)
    assert_equal({}, created)
    assert_equal({ 'wibble.txt' => intact('hello, world') }, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test '5C2q77', %w[changed content caused by string cleaning] do
    dirty = (100..1000).to_a.pack('c*').force_encoding('utf-8')
    clean = Utf8.clean(dirty)
    was_files = { 'wibble.txt' => dirty }
    now_files = { 'wibble.txt' => clean }
    created, changed = files_delta(was_files, now_files)
    assert_equal({}, created)
    assert_equal({ 'wibble.txt' => clean }, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test '5C2E79', %w[new content] do
    was_files = {}
    now_files = { 'wibble.txt' => intact('hello') }
    created, changed = files_delta(was_files, now_files)
    assert_equal({ 'wibble.txt' => intact('hello') }, created)
    assert_equal({}, changed)
  end

  # - - - - - - - - - - - - - - - - -

  test '5C2E80', %w[new empty content] do
    was_files = {}
    now_files = { 'empty.file' => intact('') }
    created, changed = files_delta(was_files, now_files)
    assert_equal({ 'empty.file' => intact('') }, created)
    assert_equal({}, changed)
  end
end
