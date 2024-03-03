require_relative '../test_base'

class PullImageTest < TestBase
  def self.id58_prefix
    '4f5'
  end

  # - - - - - - - - - - - - - - - - -

  test 'g5S', %w(
    pull_image('busybox:glibc') returns 'pulling',
    then a short while later it returns 'pulled'
  ) do
    set_context
    assert_equal 'pulling', pull_image
    count = 0
    while pull_image != 'pulled' && count < 50
      count += 1
      sleep 0.1
    end
    assert count > 0
  end

  private

  def pull_image
    runner.pull_image(id: id58, image_name: 'busybox:glibc')
  end
end
