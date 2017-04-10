require_relative 'test_base'

class NoOpTest < TestBase

  def self.hex_prefix; '24C3C'; end

  test '7E7',
  'kata_new is a no-op' do
    kata_new default_image_name, default_kata_id
  end

  test '7E8',
  'kata_new with missing args raises' do
    assert_raises {
      runner.kata_new default_image_name
    }
  end

  # - - - - - - - - - - - - - - - - -

  test 'FEE',
  'kata_old is a no-op' do
    kata_old default_image_name, default_kata_id
  end

  test 'FEF',
  'kata_old with missing args raises' do
    assert_raises {
      runner.kata_old default_image_name
    }
  end

  # - - - - - - - - - - - - - - - - -

  test 'BF8',
  'avatar_new is a no-op' do
    avatar_new default_image_name, default_kata_id, default_avatar_name, {}
  end

  test 'BF9',
  'avatar_new with missing args raises' do
    assert_raises {
      runner.avatar_new default_image_name, default_kata_id, default_avatar_name
    }
  end

  # - - - - - - - - - - - - - - - - -

  test 'DBE',
  'avatar_old is a no-op' do
    avatar_old default_image_name, default_kata_id, default_avatar_name
  end

  test 'DBF',
  'avatar_old with missing args raises' do
    assert_raises {
      avatar_old default_image_name, default_kata_id
    }
  end

end
