require_relative 'test_base'

class PullImageTest < TestBase

  def self.id58_prefix
    '4f5'
  end

  # - - - - - - - - - - - - - - - - -

  test 'g5S', %w(
  pull_image('busybox') returns 'pulling',
  then a short while later it returns 'pulled',
  and pull_image('busybox:latest') also returns 'pulled'
  ) do
    image_name = 'busybox'
    assert_equal 'pulling', runner.pull_image(id58, image_name)
    count = 0
    while runner.pull_image(id58, image_name) != 'pulled' && count < 50
      count += 1
      sleep 0.1
    end
    assert count > 0
    assert_equal 'pulled', runner.pull_image(id58, 'busybox:latest')
  end

end
