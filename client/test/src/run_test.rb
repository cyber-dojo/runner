require_relative 'test_base'

class RunTest < TestBase

  def self.hex_prefix; 'EF4356'; end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'D71',
  'invalid image_name raises' do
    error = assert_raises(StandardError) {
      sss_run({image_name:INVALID_IMAGE_NAME})
    }
    expected = 'RunnerService:run:image_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '656',
  'invalid kata_id raises' do
    error = assert_raises(StandardError) {
      sss_run({kata_id:INVALID_KATA_ID})
    }
    expected = 'RunnerService:run:kata_id:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test 'A29',
  'invalid avatar_name raises' do
    error = assert_raises(StandardError) {
      sss_run({avatar_name:INVALID_AVATAR_NAME})
    }
    expected = 'RunnerService:run:avatar_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3DF',
  'valid image_name,kata_id,avatar_name does not raise' do
    sss_run({
       image_name:VALID_IMAGE_NAME,
          kata_id:VALID_KATA_ID,
      avatar_name:VALID_AVATAR_NAME
    })
    assert_equal 'String', stdout.class.name
    assert_equal 'String', stderr.class.name
    assert_equal 'Fixnum', status.class.name
    refute_status success
    refute_status timed_out
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '743',
  'code with infinite-loop times-out' do
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
