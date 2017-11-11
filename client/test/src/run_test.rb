require_relative 'test_base'

class RunTest < TestBase

  def self.hex_prefix
    'EF4356'
  end

  # - - - - - - - - - - - - - - - - - - - - -
  # red,amber,green,timed_out
  # - - - - - - - - - - - - - - - - - - - - -

  test '3DA',
  'run with valid image_name,kata_id,avatar_name returning sssc quad' do
    run4
    assert_equal 'Integer', status.class.name
    assert_equal 'String',  stdout.class.name
    assert_equal 'String',  stderr.class.name
    assert_equal 'String',  colour.class.name
  end

end
