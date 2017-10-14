require_relative 'test_base'

class RunTest < TestBase

  def self.hex_prefix; 'EF4356'; end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'D71',
  'run raises when image_name is invalid' do
    error = assert_raises(StandardError) {
      sss_run({ image_name:INVALID_IMAGE_NAME })
    }
    expected = 'RunnerService:run:image_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '656',
  'run raises when kata_id is invalid' do
    error = assert_raises(StandardError) {
      sss_run({ kata_id:INVALID_KATA_ID })
    }
    expected = 'RunnerService:run:kata_id:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'A29',
  'run raises when avatar_name is invalid' do
    error = assert_raises(StandardError) {
      sss_run({ avatar_name:INVALID_AVATAR_NAME })
    }
    expected = 'RunnerService:run:avatar_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3DF',
  'run with valid image_name,kata_id,avatar_name returns red' do
    sss_run
    assert_colour 'red'
    assert_equal 'String',  stdout.class.name
    assert_equal 'String',  stderr.class.name
    assert_equal 'Integer', status.class.name
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '722',
  'run with very large file is red' do
    visible_files = default_visible_files
    visible_files['extra'] = 'X'*1023*500
    sss_run({ visible_files:visible_files })
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '743',
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
    sss_run({ visible_files:visible_files, max_seconds:2 })
    assert_status timed_out
  end

end
