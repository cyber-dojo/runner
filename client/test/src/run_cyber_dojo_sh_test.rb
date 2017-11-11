require_relative 'test_base'

class RunCyberDojoShTest < TestBase

  def self.hex_prefix
    'E35ACC'
  end

  # - - - - - - - - - - - - - - - - - - - - -
  # red,amber,green,timed_out
  # - - - - - - - - - - - - - - - - - - - - -

=begin

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
