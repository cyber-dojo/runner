require_relative 'test_base'

class RunTest < TestBase

  def self.hex_prefix
    'EF4356'
  end

  # - - - - - - - - - - - - - - - - - - - - -
  # raising
  # - - - - - - - - - - - - - - - - - - - - -

  test 'D71',
  'run raises when image_name is invalid' do
    error = assert_raises(StandardError) {
      sssc_run({ image_name:INVALID_IMAGE_NAME })
    }
    expected = 'RunnerService:run:image_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '656',
  'run raises when kata_id is invalid' do
    error = assert_raises(StandardError) {
      sssc_run({ kata_id:INVALID_KATA_ID })
    }
    expected = 'RunnerService:run:kata_id:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'A29',
  'run raises when avatar_name is invalid' do
    error = assert_raises(StandardError) {
      sssc_run({ avatar_name:INVALID_AVATAR_NAME })
    }
    expected = 'RunnerService:run:avatar_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -
  # red,amber,green,timed_out
  # - - - - - - - - - - - - - - - - - - - - -

  test '3DF',
  'run with valid image_name,kata_id,avatar_name returning red' do
    sssc_run
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3DE',
  'run with valid image_name,kata_id,avatar_name returning amber' do
    visible_files = default_visible_files
    visible_files['hiker.c'] = [
      '#include "hiker.h"',
      'int answer(void)',
      '{',
      '    return 6 * 9;sdsd',
      '}'
    ].join("\n")
    sssc_run({ visible_files:visible_files })
    assert_colour 'amber'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3DD',
  'run with valid image_name,kata_id,avatar_name returning green' do
    visible_files = default_visible_files
    visible_files['hiker.c'] = [
      '#include "hiker.h"',
      'int answer(void)',
      '{',
      '    return 6 * 7;',
      '}'
    ].join("\n")
    sssc_run({ visible_files:visible_files })
    assert_colour 'green'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3DC',
  'run with infinite-loop times-out' do
    visible_files = default_visible_files
    visible_files['hiker.c'] = [
      '#include "hiker.h"',
      'int answer(void)',
      '{',
      '    for(;;);',
      '    return 6 * 9;',
      '}'
    ].join("\n")
    sssc_run({ visible_files:visible_files, max_seconds:3 })
    assert_colour timed_out
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3DB',
  'run with very large file is red' do
    visible_files = default_visible_files
    visible_files['extra'] = 'X'*1023*500
    sssc_run({ visible_files:visible_files })
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3DA',
  'run with valid image_name,kata_id,avatar_name returning sssc quad' do
    sssc_run
    assert_equal 'String', colour.class.name
    assert_equal 'String', stdout.class.name
    assert_equal 'String', stderr.class.name
  end

end
