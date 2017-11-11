require_relative 'test_base'

class RunCyberDojoShTest < TestBase

  def self.hex_prefix
    'E35ACC'
  end

  # - - - - - - - - - - - - - - - - - - - - -
  # raising
  # - - - - - - - - - - - - - - - - - - - - -

  # - - - - - - - - - - - - - - - - - - - - -

  test '656',
  'raises when kata_id is invalid' do
    error = assert_raises(StandardError) {
      run_cyber_dojo_sh({ kata_id:INVALID_KATA_ID })
    }
    expected = 'RunnerService:run_cyber_dojo_sh:kata_id:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -

=begin
  test 'A29',
  'run raises when avatar_name is invalid' do
    error = assert_raises(StandardError) {
      run4({ avatar_name:INVALID_AVATAR_NAME })
    }
    expected = 'RunnerService:run:avatar_name:invalid'
    assert_equal expected, error.message
  end

  # - - - - - - - - - - - - - - - - - - - - -
  # red,amber,green,timed_out
  # - - - - - - - - - - - - - - - - - - - - -

  test '3DF',
  'run with valid image_name,kata_id,avatar_name returning red' do
    run4
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
    run4({ visible_files:visible_files })
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
    run4({ visible_files:visible_files })
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
    run4({ visible_files:visible_files, max_seconds:3 })
    assert_colour timed_out
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3DB',
  'run with very large file is red' do
    visible_files = default_visible_files
    visible_files['extra'] = 'X'*1023*500
    run4({ visible_files:visible_files })
    assert_colour 'red'
  end

  # - - - - - - - - - - - - - - - - - - - - -

  test '3DA',
  'run with valid image_name,kata_id,avatar_name returning sssc quad' do
    run4
    assert_equal 'Integer', status.class.name
    assert_equal 'String',  stdout.class.name
    assert_equal 'String',  stderr.class.name
    assert_equal 'String',  colour.class.name
  end
=end

end
